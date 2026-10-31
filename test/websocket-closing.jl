
@testset "WebSocket Connection Closing Tests" begin
    @testset "Connection State After Browser Close" begin
        app = App() do session, request
            return DOM.div(
                "WebSocket Close Test",
                dataTestId="websocket-test"
            )
        end
        display(edisplay, app)
        session = app.session[]

        # Wait for connection to be established
        success = Bonito.wait_for(timeout=5) do
            result = run(edisplay.window, "window.WEBSOCKET && window.WEBSOCKET.isopen()")
            return result == true
        end
        @test success == :success
    end

    @testset "Direct WebSocket Close Behavior" begin
        app = App() do session, request
            return DOM.div(
                "Direct Close Test",
                dataTestId="direct-close-test"
            )
        end
        display(edisplay, app)
        session = app.session[]

        # Wait for connection
        Bonito.wait_for(timeout=5) do
            run(edisplay.window, "window.WEBSOCKET && window.WEBSOCKET.isopen()")
        end

        # Close the websocket directly
        wsopen = run(edisplay.window, """
            window.WEBSOCKET.close();
            window.WEBSOCKET.isopen();
        """)
        # Check that websocket is closed after direct close
        @test false == wsopen
        success = Bonito.wait_for(timeout=5) do
            # Test reconnect!
            return run(edisplay.window, "window.WEBSOCKET.isopen()")
        end
        @test success == :success
        @test isopen(session)
        @test isopen(Bonito.root_session(session))
        @test isready(Bonito.root_session(session))
    end
end

mutable struct PausedSocketCleanup <: Bonito.CleanupPolicy
    checked::Channel{Nothing}
    resume::Base.Event
    paused::Threads.Atomic{Bool}
    soft::Bool
end
Bonito.should_cleanup(::PausedSocketCleanup, ::Session) = false
function Bonito.allow_soft_close(policy::PausedSocketCleanup)
    if !Threads.atomic_xchg!(policy.paused, true)
        put!(policy.checked, nothing)
        wait(policy.resume)
    end
    return policy.soft
end

@testset "a departing socket cannot close its replacement" begin
    for Connection in (Bonito.WebSocketConnection, Bonito.DualWebsocket), soft in (false, true)
        server = Server("127.0.0.1", 0)
        connection = Connection(server)
        session = Session(connection; asset_server = Bonito.NoServer())
        policy = PausedSocketCleanup(Channel{Nothing}(1), Base.Event(), Threads.Atomic{Bool}(false), soft)
        previous = Bonito.CLEANUP_POLICY[]
        done = Base.Event()
        sockets = Channel{HTTP.WebSockets.WebSocket}(2)
        clients = Task[]
        try
            Bonito.setup_connection(session)
            session.status = Bonito.OPEN
            Bonito.set_cleanup_policy!(policy)
            query = Connection === Bonito.DualWebsocket ? "?low_latency" : ""
            url = "ws://127.0.0.1:$(server.port)/$(session.id)$(query)"
            connect() = push!(clients, @async HTTP.WebSockets.open(url) do socket
                put!(sockets, socket)
                wait(done)
            end)
            connect()
            @test Bonito.wait_for(() -> isready(sockets)) == :success
            original = take!(sockets)
            original.close_transport!()
            @test Bonito.wait_for(() -> isready(policy.checked)) == :success
            connect()
            @test Bonito.wait_for(() -> isready(sockets)) == :success
            replacement = take!(sockets)
            handler = first(Bonito.websocket_handlers(connection))
            @test Bonito.wait_for(() -> isopen(handler)) == :success
            notify(policy.resume)
            sleep(0.1) # let the old loop finish its paused cleanup
            @test !replacement.readclosed
            @test session.status === Bonito.OPEN
            @test isopen(handler)
        finally
            notify(policy.resume)
            notify(done)
            Bonito.set_cleanup_policy!(previous)
            close(session)
            close(server)
            foreach(wait, clients)
        end
    end
end
