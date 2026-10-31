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

@testset "listener lifecycle uses the session-tree lock" begin
    root = Session()
    shared = Observable(0)
    try
        tasks = map(1:max(4, Threads.nthreads())) do _
            Threads.@spawn for _ in 1:500
                sub = Session(root)
                map(x -> x + 1, sub, shared)
                on(identity, sub, shared)
                Bonito.SerializedMessage(sub, shared)
                Bonito.update_nocycle!(shared, 0, root)
                close(sub)
            end
        end
        foreach(wait, tasks)
        @test isempty(shared.listeners)
        @test isempty(root.children)
        @test isempty(root.session_objects)
    finally
        close(root)
    end
end

@testset "a blocked registration does not block independent sessions" begin
    first, second = Session(), Session()
    blocked_obs, independent_obs = Observable(0), Observable(0)
    entered, release = Channel{Nothing}(1), Base.Event()
    hook = function (_, observable)
        if observable === blocked_obs
            put!(entered, nothing)
            wait(release)
        end
    end
    tasks = Task[]
    push!(Observables.addhandler_callbacks, hook)
    try
        push!(tasks, @async on(identity, first, blocked_obs))
        @test Bonito.wait_for(() -> isready(entered)) == :success
        push!(tasks, Threads.@spawn begin
            on(identity, second, independent_obs)
            onany((a, b) -> nothing, second, independent_obs, Observable(0))
            Bonito.update_nocycle!(independent_obs, 1, second)
            empty!(second)
            on(identity, second, independent_obs)
            close(second)
        end)
        @test Bonito.wait_for(() -> istaskdone(last(tasks))) == :success
        @test isempty(independent_obs.listeners)
    finally
        notify(release)
        try
            foreach(wait, tasks)
        finally
            filter!(f -> f !== hook, Observables.addhandler_callbacks)
            close(first)
            close(second)
        end
    end
end

Bonito.set_cleanup_time!(30/60/60)
