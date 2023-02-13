const THREE = ES6Module("https://cdn.esm.sh/v66/three@0.136/es2021/three.js")

function export_test_app(session, request)
    result = DOM.div("failed"; dataTestId="result")
    return DOM.div(
        result,
        js"""
            const three = await $(THREE)
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
    result = run(window, "$(query_testid("result")).innerText")
    @test result == "passed"
    close(window)
    close(app)
end
rm(path; force=true)


# Finalizers and other problems have been closing our connection unintentional,
# So we do this little stress test:
edisplay = JSServe.use_electron_display()

@testset "GC connection test" begin
    app = App(export_test_app)
    for i in 1:50
        display(edisplay, app)
        success = JSServe.wait_for(timeout=5) do
            result = run(edisplay.window, "$(query_testid("result")).innerText")
            return result == "passed"
        end
        @test success == :success
        GC.gc()
    end
    session = app.session[]
    @test session.connection isa JSServe.SubConnection
    @test parent(session).connection isa JSServe.WebSocketConnection
    @test isready(parent(session))
end
