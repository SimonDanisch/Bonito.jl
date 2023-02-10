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
server = Server("0.0.0.0", 8888)
connections = [()-> NoConnection(), ()-> WebSocketConnection(server)]
servers = [()-> NoServer(), ()-> HTTPAssetServer(server)]

path = joinpath(@__DIR__, "test.html")
@testset "connection $(typeof(connection)) server: $(typeof(server))" for (connection, server) in Iterators.product(connections, servers)
    app = App(export_test_app)
    export_static(path, app; connection=connection(), asset_server=server())
    # We need to drop a bit lower and cant use `testapp` here, since that uses fixed connection + asset server
    window = Window(URI(path))
    result = run(window, "$(query_testid("result")).innerText")
    @test result == "passed"
    close(window)
    close(app)
end
rm(path; force=true)
