const THREE = ES6Module(joinpath(@__DIR__, "three.js"))

function export_test_app(session, request)
    result = DOM.div("failed"; dataTestId="result")
    return DOM.div(
        result,
        js"""
            const three = await $(THREE)
            console.log(three)
            if ('AdditiveAnimationBlendMode' in three) {
                $(result).innerText = "passed"
            }
        """
    )
end

connections = [(:NoConnection, ()-> NoConnection()), (:WebSocketConnection, ()-> WebSocketConnection())]
servers = [(:NoServer, () -> NoServer()), (:HTTPAssetServer, () -> HTTPAssetServer())]

path = joinpath(@__DIR__, "test.html")
@testset "connection $(c) server: $(s)" for ((c, connection), (s, server)) in Iterators.product(connections, servers)
    app = App(export_test_app)
    export_static(path, app; connection=connection(), asset_server=server())
    # We need to drop a bit lower and cant use `testapp` here, since that uses fixed connection + asset server
    window = Window(URI("file://" * path))
    sleep(0.5) # how did this work before without syncronization?
    result = run(window, "$(query_testid("result")).innerText")
    @test result == "passed"
    close(window)
    close(app)
end
rm(path; force=true)

# Finalizers and other problems have been closing our connection unintentional,
# So we do this little stress test:
@testset "GC connection test" begin
    app = App(export_test_app)
    @testset for i in 1:50
        display(edisplay, app)
        s = app.session[]
        p = parent(s)
        success = Bonito.wait_for(timeout=5) do
            result = run(edisplay.window, "$(query_testid("result")).innerText")
            return result == "passed"
        end
        @test success == :success
        GC.gc()
    end
    session = app.session[]
    @test session.connection isa Bonito.SubConnection
    @test parent(session).connection isa Bonito.WebSocketConnection
    @test isready(parent(session))
end

@testset "websocket cleanup policy test" begin
    policy = Bonito.DefaultCleanupPolicy(30, 2.0)

    # New session shouldn't be cleaned up
    session = Session(WebSocketConnection())
    @test !Bonito.should_cleanup(policy, session)

    # Displayed session that hasn't connected shouldn't be cleaned up immediately
    session.status = Bonito.DISPLAYED
    session.closing_time = time()
    @test !Bonito.should_cleanup(policy, session)

    # Displayed session that hasn't connected should be cleaned up after wait time
    session.closing_time = time() - 31
    @test Bonito.should_cleanup(policy, session)

    # Soft closed session shouldn't be cleaned up immediately
    session.status = Bonito.SOFT_CLOSED
    session.closing_time = time()
    @test !Bonito.should_cleanup(policy, session)

    # Soft closed session should be cleaned up after cleanup time
    session.closing_time = time() - 3 * 60 * 60  # 3 hours
    @test Bonito.should_cleanup(policy, session)

    # allow_soft_close should return true when cleanup_time > 0
    @test Bonito.allow_soft_close(policy)

    # allow_soft_close should return false when cleanup_time = 0
    zero_policy = Bonito.DefaultCleanupPolicy(30, 0.0)
    @test !Bonito.allow_soft_close(zero_policy)

    struct TrivialCleanupPolicy <: Bonito.CleanupPolicy end

    Bonito.should_cleanup(::TrivialCleanupPolicy, ::Session) = true
    Bonito.allow_soft_close(::TrivialCleanupPolicy) = false

    original_cleanup_policy = Bonito.CLEANUP_POLICY[]
    try
        Bonito.set_cleanup_policy!(TrivialCleanupPolicy())

        session = Session(WebSocketConnection())
        @test Bonito.should_cleanup(Bonito.CLEANUP_POLICY[], session)
    finally
        Bonito.set_cleanup_policy!(original_cleanup_policy)
    end
end
