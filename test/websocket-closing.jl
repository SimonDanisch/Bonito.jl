
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
