import Bonito.HTTPServer: online_url, local_url, relative_url
Bonito.set_cleanup_time!(0.0)
@testset "server cleanup" begin
    Bonito.Bonito.set_cleanup_time!(5 / 60 / 60) # 1 second

    app = App() do session
        dropdown1 = Bonito.Dropdown(["a", "b", "c"])
        dropdown2 = Bonito.Dropdown(["a2", "b2", "c2"]; index=2)
        img = Asset(joinpath(@__DIR__, "..", "docs", "src", "jupyterlab.png"))
        return DOM.div(dropdown1, dropdown2, img, js"""$(Bonito.BonitoLib).then(console.log)""")
    end
    server = Server(app, "0.0.0.0", 8898)

    window = TestWindow()
    url = URI(online_url(server, "/"))
    @testset for i in 1:10
        ElectronCall.load(window.window, url)
        @test test_dom(window) # re-use from threading.jl
    end
    if app.session[].connection isa Bonito.DualWebsocket
        @test length(server.websocket_routes.table) == 20
        success = Bonito.wait_for(()-> length(server.websocket_routes.table) == 2, timeout=10)
    else
        @test length(server.websocket_routes.table) == 10
        success = Bonito.wait_for(()-> length(server.websocket_routes.table) == 1, timeout=10)
    end
    @test success == :success
    close(window)
    success = Bonito.wait_for(() -> isempty(server.websocket_routes.table), timeout=10)
    @test success == :success
    close(server)
    Bonito.Bonito.set_cleanup_time!(0.0)
end

@testset "proxy_url" begin
    server = Server("0.0.0.0", 8787)
    port = server.port # just in case this 8787 is used already somehow
    @testset "default" begin
        @test server.proxy_url == ""
        @test online_url(server, "") == "http://localhost:$(port)"
        @test local_url(server, "") == "http://localhost:$(port)"
        @test relative_url(server, "") == "http://localhost:$(port)"
    end

    @testset "relative urls" begin
        server.proxy_url = "."
        @test online_url(server, "") == "http://localhost:$(port)"
        @test local_url(server, "") == "http://localhost:$(port)"
        # `proxy_url == "."` returns server-absolute paths so sub-routes like
        # `/p/<id>` resolve assets correctly (changed in 57d9b73). Empty url
        # → just "/", non-empty preserves its leading slash.
        @test relative_url(server, "") == "/"
        @test relative_url(server, "assets/x") == "/assets/x"
        @test relative_url(server, "/already/abs") == "/already/abs"
    end
    @testset "absolute urls" begin
        server.proxy_url = "https://bonito.makie.org"
        @test online_url(server, "") == "https://bonito.makie.org/"
        @test local_url(server, "") == "http://localhost:$(port)"
        @test relative_url(server, "") == "https://bonito.makie.org/"
    end
    close(server)
end
@testset "served pages are uncacheable (Cache-Control: no-store)" begin
    # The session id is baked into the HTML, so a cached page would revive a
    # fresh page against a dead session (broken DOM, "double freeing session").
    app = App(() -> DOM.div("cache-header-check"))
    server = Server("0.0.0.0", 0)
    try
        route!(server, "/" => app)
        resp = HTTP.get("http://localhost:$(server.port)/")
        cc = [v for (k, v) in resp.headers if lowercase(k) == "cache-control"]
        @test cc == ["no-store"]
        # Two plain fetches must mint DIFFERENT sessions (the id is baked into
        # the page): if this ever fails the server itself started replaying
        # session HTML, which no cache header can save.
        body1 = String(resp.body)
        body2 = String(HTTP.get("http://localhost:$(server.port)/").body)
        @test body1 != body2
    finally
        close(server)
    end
end

@testset "request target forwarded to handler" begin
    # Regression test: `route!(server, r".*" => app)` must forward the HTTP
    # request into the app handler so `r.target` reflects the requested path
    # (broke in #389 when apply_handler stopped threading context.request).
    # target is rendered verbatim as a text node; use distinctive slash paths
    # (letters/slashes aren't HTML entity-escaped, unlike `=`, `[`, `<`).
    app = App() do session, request
        return DOM.div(request.target)
    end
    server = Server("0.0.0.0", 0)
    port = server.port
    try
        route!(server, r".*" => app)
        @test occursin("/hello/world",
            String(HTTP.get("http://localhost:$(port)/hello/world").body))
        # a second request renders its own target, not the previous one's
        body2 = String(HTTP.get("http://localhost:$(port)/second/path").body)
        @test occursin("/second/path", body2)
        @test !occursin("/hello/world", body2)
    finally
        close(server)
    end
end

# A gate in front of every route: here, only requests with the right key pass,
# and what it lets through carries who it let in.
struct KeyGate
    key::String
end
function Bonito.HTTPServer.gate_request(g::KeyGate, request)
    HTTP.removeheader(request, "X-Who")                  # only the gate says who
    HTTP.header(request, "X-Key", "") == "boom" && error("the gate broke")
    HTTP.header(request, "X-Key", "") == g.key ||
        return HTTP.Response(401, ["Cache-Control" => "no-store"], "no entry")
    HTTP.setheader(request, "X-Who" => "admitted")
    return nothing
end
Bonito.HTTPServer.gate_response(::KeyGate, request, response) =
    (HTTP.setheader(response, "X-Gated" => "yes"); response)

@testset "gate" begin
    server = Server("127.0.0.1", 0; gate = KeyGate("sesame"))
    url = "http://127.0.0.1:$(server.port)"
    try
        route!(server, "/who" => ctx -> HTTP.Response(200, HTTP.header(ctx.request, "X-Who", "nobody")))
        Bonito.HTTPServer.websocket_route!(server, "/echo" => (ctx, ws) -> foreach(m -> HTTP.WebSockets.send(ws, m), ws))
        get(key; who = "") = HTTP.get("$(url)/who", ["X-Key" => key, "X-Who" => who]; status_exception = false, retry = false)
        # Refused before any route: the route never runs, the gate's answer is final.
        r = get("wrong")
        @test r.status == 401 && String(r.body) == "no entry" && HTTP.header(r, "X-Gated") == ""
        # Let through, with what the gate set; a client's own X-Who never survives.
        r = get("sesame"; who = "forged")
        @test r.status == 200 && String(r.body) == "admitted" && HTTP.header(r, "X-Gated") == "yes"
        # Unknown routes are the gate's business too.
        @test HTTP.get("$(url)/nothing-here"; status_exception = false).status == 401
        # A gate that throws refuses, and says nothing about why.
        r = get("boom")
        @test r.status == 500 && !occursin("broke", String(r.body))
        # Websocket upgrades pass the gate first: refused without the key...
        @test_throws Exception HTTP.WebSockets.open(ws -> nothing, "ws://127.0.0.1:$(server.port)/echo";
                                                    headers = ["X-Key" => "wrong"])
        # ...served with it.
        echoed = HTTP.WebSockets.open("ws://127.0.0.1:$(server.port)/echo"; headers = ["X-Key" => "sesame"]) do ws
            HTTP.WebSockets.send(ws, "hi")
            HTTP.WebSockets.receive(ws)
        end
        @test echoed == "hi"
    finally
        close(server)
    end
    # Without a gate nothing changes.
    open_server = Server("127.0.0.1", 0)
    try
        route!(open_server, "/who" => ctx -> HTTP.Response(200, "anyone"))
        @test String(HTTP.get("http://127.0.0.1:$(open_server.port)/who").body) == "anyone"
    finally
        close(open_server)
    end
end

Bonito.set_cleanup_time!(30/60/60)
