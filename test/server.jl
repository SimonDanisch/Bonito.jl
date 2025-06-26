import Bonito.HTTPServer: online_url, local_url, relative_url
Bonito.WEBSOCKET_CLEANUP[] = 0.0
@testset "server cleanup" begin
    Bonito.set_cleanup_time!(5 / 60 / 60) # 1 second

    app = App() do session
        dropdown1 = Bonito.Dropdown(["a", "b", "c"])
        dropdown2 = Bonito.Dropdown(["a2", "b2", "c2"]; index=2)
        img = Asset(joinpath(@__DIR__, "..", "docs", "src", "jupyterlab.png"))
        return DOM.div(dropdown1, dropdown2, img, js"""$(Bonito.BonitoLib).then(console.log)""")
    end
    server = Server(app, "0.0.0.0", 8898)

    window = Bonito.EWindow()
    url = URI(online_url(server, "/"))
    @testset for i in 1:10
        load(window.window, url)
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
    Bonito.set_cleanup_time!(0.0)
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
        @test relative_url(server, "") == "./"
    end
    @testset "absolute urls" begin
        server.proxy_url = "https://bonito.makie.org"
        @test online_url(server, "") == "https://bonito.makie.org/"
        @test local_url(server, "") == "http://localhost:$(port)"
        @test relative_url(server, "") == "https://bonito.makie.org/"
    end
    close(server)
end
Bonito.WEBSOCKET_CLEANUP[] = 30.0
