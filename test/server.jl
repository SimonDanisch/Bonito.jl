@testset "server cleanup" begin
    JSServe.set_cleanup_time!(5 / 60 / 60) # 1 second

    app = App() do session
        dropdown1 = JSServe.Dropdown(["a", "b", "c"])
        dropdown2 = JSServe.Dropdown(["a2", "b2", "c2"]; index=2)
        img = Asset(joinpath(@__DIR__, "..", "docs", "src", "jupyterlab.png"))
        return DOM.div(dropdown1, dropdown2, img, js"""$(JSServe.JSServeLib).then(console.log)""")
    end
    server = Server(app, "0.0.0.0", 8898)

    window = Window(Application())
    url = URI(online_url(server, "/"))
    @testset for i in 1:10
        load(window, url)
        @test test_dom(window) # re-use from threading.jl
    end
    @test length(server.websocket_routes.table) == 10
    success = JSServe.wait_for(()-> length(server.websocket_routes.table) == 1, timeout=10)
    @test success == :success
    close(window)
    success = JSServe.wait_for(() -> isempty(server.websocket_routes.table), timeout=10)
    @test success == :success
    close(server)
    JSServe.set_cleanup_time!(0.0) # 1 second

end
