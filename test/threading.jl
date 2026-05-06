# electron_evaljs, is_fully_loaded, test_dom defined in test_helpers.jl

# Disable cleanup wait so that we can test if all sessions close properly
# After closing the windows!
Bonito.set_cleanup_time!(0.0)
@testset "stresstest threading" begin
    app = App() do session
        dropdown1 = Bonito.Dropdown(["a", "b", "c"])
        dropdown2 = Bonito.Dropdown(["a2", "b2", "c2"]; index=2)
        img = Asset(joinpath(@__DIR__, "..", "docs", "src", "jupyterlab.png"))
        return DOM.div(dropdown1, dropdown2, img, js"""$(Bonito.BonitoLib).then(console.log)""")
    end
    server = Server(app, "0.0.0.0", 8888)

    nwindows = 4
    all_windows = Channel{Bonito.EWindow}(nwindows)
    created_windows = Bonito.EWindow[]
    for i in 1:nwindows
        win = TestWindow()
        put!(all_windows, win)
        push!(created_windows, win)
    end
    url = URI(online_url(server, "/"))
    # Only use half of the available threads to not block the response because we hogged all threads
    results = asyncmap(1:100) do i
        window = take!(all_windows)
        try
            ElectronCall.load(window.window, url)
            return test_dom(window)
        finally
            put!(all_windows, window)
        end
    end
    @test all(results)
    for win in created_windows
        close(win)
    end
    empty!(created_windows)
    success = Bonito.wait_for(() -> isempty(server.websocket_routes.table), timeout=10)
    @test success == :success
    close(server)
end
Bonito.set_cleanup_time!(30/60/60)
