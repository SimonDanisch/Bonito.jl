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

connections = [NoConnection(), WebSocketConnection()]
servers = [NoServer(), HTTPAssetServer()]

@testset "connection $(typeof(connection)) server: $(typeof(server))" for (connection, server) in Iterators.product(connections, servers)
    JSServe.force_connection!(connection)
    JSServe.force_asset_server!(server)
    testsession(export_test_app, port=8555) do app
        bquery = evaljs(app, js"""$(query_testid("result")).innerText""")
        @test "passed" == bquery
    end
end
