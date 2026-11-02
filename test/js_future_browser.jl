using Bonito, ElectronCall, Test

function future_browser_app(events)
    return App() do session
        command = Observable("idle")
        traffic = Observable(0)
        count = Observable(0)
        status = Observable("idle")
        on(session, traffic) do value
            push!(events, value)
            count[] = length(events)
        end
        on(session, command) do mode
            status[] = try
                value = if mode == "child"
                    fetch(@async fetch(evaljs_async(session, js"42"; timeout=2)))
                elseif mode == "burst"
                    evaljs_value(session, js"(() => { for (let i=1; i<=1100; i++) $(traffic).notify(i); return 42; })()"; timeout=2)
                else
                    evaljs_value(session, js"Promise.resolve(42)"; timeout=2)
                end
                string(mode, ":", value)
            catch err
                string(mode, ":", sprint(showerror, err))
            end
        end
        DOM.div(
            [DOM.button(mode; id=mode, onclick=js"() => $(command).notify($mode)") for mode in ("direct", "child", "burst")],
            DOM.span(status; id="future-status"), DOM.span(count; id="event-count"),
            DOM.span(traffic; id="traffic"),
        )
    end
end

@testset "JavaScript futures through real browser messages" begin
    for compressed in (false, true), embedded in (false, true)
        Bonito.use_compression!(compressed)
        events = Int[]
        child = future_browser_app(events)
        app = embedded ? App(session -> Bonito.embed_app(session, child)) : child
        server = Bonito.Server(app, "127.0.0.1", 0)
        window = TestWindow()
        try
            ElectronCall.load(window.window, Bonito.URI(Bonito.online_url(server, "/")))
            @test Bonito.wait_for(; timeout=20) do
                child.session[] !== nothing && Bonito.isready(child.session[])
            end == :success
            for mode in ("direct", "child", "burst")
                run(window, "document.querySelector('#$(mode)').click()")
                @test Bonito.wait_for(; timeout=6) do
                    startswith(run(window, "document.querySelector('#future-status').textContent"), mode * ":")
                end == :success
                @test run(window, "document.querySelector('#future-status').textContent") == "$(mode):42"
            end
            @test Bonito.wait_for(() -> length(events) == 1100; timeout=5) == :success
            @test events == collect(1:1100)

            session = child.session[]
            first = evaljs_async(session, js"new Promise(resolve => { document.body.releaseRequest = resolve; })"; timeout=5)
            second = evaljs_async(session, js"Promise.resolve(2)"; timeout=5)
            @test fetch(second) == 2
            @test !isready(first)
            run(window, "document.body.releaseRequest(1)")
            @test fetch(first) == 1
            @test fetch(second) == 2
            @test_throws "rejected" evaljs_value(session, js"Promise.reject(new Error('rejected'))")
            @test_throws "sync failure" evaljs_value(session, js"(() => { throw new Error('sync failure') })()")
            # evaljs_value keeps accepting what callers already pass it.
            @test evaljs_value(session, js"1 + 1;") == 2
            @test evaljs_value(session, js"1 + 1 // trailing comment") == 2
            @test evaljs_value(session, js"1 + 1; document.title") == 2
            @test evaljs_value(session, js"undefined") === nothing
            # A result the protocol cannot encode reports that, instead of timing out.
            for unencodable in (js"(() => { const c = {}; c.c = c; return c; })()", js"(() => 1)")
                @test_throws ErrorException evaljs_value(session, unencodable; timeout=5)
            end

            pending = evaljs_async(session, js"new Promise(resolve => { document.body.lateReply = resolve; })"; timeout=10)
            @test Bonito.wait_for(() -> run(window, "typeof document.body.lateReply === 'function'"); timeout=5) == :success
            run(window, "window.WEBSOCKET.close()")
            @test Bonito.wait_for(() -> isready(pending); timeout=3) == :success
            @test_throws "disconnected" fetch(pending)
            @test Bonito.wait_for(() -> run(window, "window.WEBSOCKET.isopen()"); timeout=15) == :success
            @test Bonito.wait_for(() -> Bonito.isready(session); timeout=5) == :success
            run(window, "document.body.lateReply('old'); document.querySelector('#direct').click()")
            @test Bonito.wait_for(() -> run(window, "document.querySelector('#future-status').textContent") == "direct:42"; timeout=5) == :success
        finally
            close(window)
            close(server)
        end
    end
    Bonito.use_compression!(false)
end
