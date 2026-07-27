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

Bonito.set_cleanup_time!(30/60/60)
