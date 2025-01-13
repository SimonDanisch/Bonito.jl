@testset "server cleanup" begin
    Bonito.set_cleanup_time!(5 / 60 / 60) # 1 second

    app = App() do session
        dropdown1 = Bonito.Dropdown(["a", "b", "c"])
        dropdown2 = Bonito.Dropdown(["a2", "b2", "c2"]; index=2)
        img = Asset(joinpath(@__DIR__, "..", "docs", "src", "jupyterlab.png"))
        return DOM.div(dropdown1, dropdown2, img, js"""$(Bonito.BonitoLib).then(console.log)""")
    end
    server = Server(app, "0.0.0.0", 8898)

    window = Window(Application())
    url = URI(online_url(server, "/"))
    @testset for i in 1:10
        load(window, url)
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

using RelocatableFolders

@testset "Asset serving and Path" begin
    asset = Asset(@path joinpath(@__DIR__, "serialization.jl"))
    @test Bonito.serving_target(asset) isa RelocatableFolders.Path
    @test isfile(Bonito.serving_target(asset))
    @test read(Bonito.serving_target(asset)) isa Vector{UInt8}
end

@testset "get online URL" begin
    App() do session::Session
        server = get_server(session)
        DOM.div(string(Bonito.online_url(server, "")))
    end
end
