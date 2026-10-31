using Bonito, Test, Logging

# Run before opening test windows: cleanup_globals deliberately resets the
# process-wide display server, just as it does at the end of precompilation.
@testset "cleanup leaves no pending timer (#430)" begin
    @testset "close server, task started = $started" for started in (false, true)
        server = Bonito.Server("127.0.0.1", 0)
        task, timer = Bonito.add_cleanup_task!(server)
        try
            started && yield()
            close(server)
            @test !isopen(timer)
            @test istaskdone(task)
            @test !istaskfailed(task)
            @test !haskey(Bonito.SERVER_CLEANUP_TASKS, server)
            close(server) # idempotent
        finally
            close(server)
        end
    end

    @testset "cleanup callback can close its own server" begin
        server = Bonito.Server("127.0.0.1", 0)
        session = Bonito.Session(Bonito.WebSocketConnection(server); asset_server = Bonito.NoServer())
        Bonito.setup_connection(session)
        task, timer = Bonito.SERVER_CLEANUP_TASKS[server]
        Bonito.mark_displayed!(session)
        session.closing_time = time() - 3600
        Bonito.on(session.on_close) do _
            close(server)
        end
        try
            @test timedwait(() -> istaskdone(task), 5) == :ok
            @test !istaskfailed(task)
            @test !isopen(timer)
            @test !haskey(Bonito.SERVER_CLEANUP_TASKS, server)
        finally
            close(server)
        end
    end

    @testset "precompile serve workload and global cleanup" begin
        app = Bonito.App() do session
            slider = Bonito.Slider(1:10)
            Bonito.DOM.div(slider)
        end
        try
            @test_logs min_level=Logging.Warn Bonito.serve_workload(app)
            entries = collect(values(Bonito.SERVER_CLEANUP_TASKS))
            @test !isempty(entries)
            Bonito.cleanup_globals()
            @test isempty(Bonito.SERVER_CLEANUP_TASKS)
            @test isnothing(Bonito.GLOBAL_SERVER[])
            @test all(((task, timer),) -> istaskdone(task) && !istaskfailed(task) && !isopen(timer), entries)
            Bonito.cleanup_globals() # idempotent
        finally
            Bonito.cleanup_globals()
        end
    end
end
