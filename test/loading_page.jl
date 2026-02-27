@testset "LoadingPage Construction" begin
    # Default: no loading page
    app1 = App(() -> DOM.div("hello"))
    @test isnothing(app1.loading_page)

    # With loading page
    lp = LoadingPage()
    app2 = App(() -> DOM.div("hello"); loading_page=lp)
    @test app2.loading_page === lp

    # With custom loading page
    lp_custom = LoadingPage(text="Please wait...")
    app3 = App(() -> DOM.div("hello"); loading_page=lp_custom)
    @test app3.loading_page.text == "Please wait..."

    # Dom object constructor
    app4 = App(DOM.div("static"); loading_page=LoadingPage())
    @test !isnothing(app4.loading_page)

    # All handler signatures work with loading_page
    app_a = App((session, request) -> DOM.div(); loading_page=LoadingPage())
    app_b = App((session) -> DOM.div(); loading_page=LoadingPage())
    app_c = App(() -> DOM.div(); loading_page=LoadingPage())
    for a in [app_a, app_b, app_c]
        @test !isnothing(a.loading_page)
    end
end

@testset "LoadingPage - no loading_page preserves behavior" begin
    app = App() do session
        return DOM.div("no loading page"; class="no-lp")
    end
    display(edisplay, app)
    Bonito.wait_for_ready(app)
    success = Bonito.wait_for() do
        evaljs_value(app.session[], js"""
            document.querySelector('.no-lp') !== null
        """)
    end
    @test success == :success
end

@testset "LoadingPage - shown then replaced" begin
    gate = Channel{Nothing}(1)
    handler_started = Ref(false)

    app = App(; loading_page=LoadingPage(text="Test Loading...")) do session
        handler_started[] = true
        take!(gate) # wait for test to release
        return DOM.div("Real Content"; class="real-content")
    end

    try
        display(edisplay, app)
        Bonito.wait_for_ready(app)

        # Loading page should be visible initially
        success = Bonito.wait_for(timeout=10) do
            evaljs_value(app.session[], js"""
                document.querySelector('.bonito-loading-container') !== null
            """)
        end
        @test success == :success

        # Verify loading text
        text = evaljs_value(app.session[], js"""(() => {
            const el = document.querySelector('.bonito-loading-text');
            return el ? el.textContent : null;
        })()""")
        @test text == "Test Loading..."

        # Release the handler
        put!(gate, nothing)

        # Real content should appear and loading page should be gone
        success = Bonito.wait_for(timeout=10) do
            evaljs_value(app.session[], js"""
                document.querySelector('.real-content') !== null
            """)
        end
        @test success == :success

        loading_gone = evaljs_value(app.session[], js"""
            document.querySelector('.bonito-loading-container') === null
        """)
        @test loading_gone === true

        content = evaljs_value(app.session[], js"""
            document.querySelector('.real-content').textContent
        """)
        @test content == "Real Content"
    finally
        # Ensure gate is released so the @async handler doesn't hang forever
        isready(gate) || put!(gate, nothing)
    end
end

@testset "LoadingPage - fast handler (no visible loading)" begin
    # When handler is instant, loading page may not be visible,
    # but the real content should still render correctly
    app = App(; loading_page=LoadingPage()) do session
        return DOM.div("Fast Content"; class="fast-content")
    end
    display(edisplay, app)
    Bonito.wait_for_ready(app)

    success = Bonito.wait_for(timeout=10) do
        evaljs_value(app.session[], js"""
            document.querySelector('.fast-content') !== null
        """)
    end
    @test success == :success

    content = evaljs_value(app.session[], js"""
        document.querySelector('.fast-content').textContent
    """)
    @test content == "Fast Content"
end

@testset "LoadingPage - observables in real DOM" begin
    # Critical regression test: observables inside the handler's DOM
    # must still work when everything is wrapped in an Observable
    obs_val = Observable("initial")

    app = App(; loading_page=LoadingPage()) do session
        return DOM.div(obs_val; class="obs-container")
    end
    display(edisplay, app)
    Bonito.wait_for_ready(app)

    # Wait for real content to appear
    success = Bonito.wait_for(timeout=10) do
        evaljs_value(app.session[], js"""
            document.querySelector('.obs-container') !== null
        """)
    end
    @test success == :success

    # Check initial value rendered
    success = Bonito.wait_for(timeout=10) do
        result = evaljs_value(app.session[], js"""
            document.querySelector('.obs-container').textContent
        """)
        occursin("initial", result)
    end
    @test success == :success

    # Update the observable - should propagate to DOM
    obs_val[] = "updated"
    success = Bonito.wait_for(timeout=10) do
        result = evaljs_value(app.session[], js"""
            document.querySelector('.obs-container').textContent
        """)
        occursin("updated", result)
    end
    @test success == :success
end

@testset "LoadingPage - widgets work" begin
    btn_clicked = Ref(false)

    app = App(; loading_page=LoadingPage()) do session
        button = Button("Click Me")
        on(session, button.value) do _
            btn_clicked[] = true
        end
        return DOM.div(button; class="widget-container")
    end
    display(edisplay, app)
    Bonito.wait_for_ready(app)

    # Wait for button to render
    success = Bonito.wait_for(timeout=10) do
        evaljs_value(app.session[], js"""
            document.querySelector('.widget-container button') !== null
        """)
    end
    @test success == :success

    # Click the button
    evaljs(app.session[], js"""
        document.querySelector('.widget-container button').click()
    """)

    # Wait for click to propagate
    success = Bonito.wait_for(timeout=10) do
        btn_clicked[]
    end
    @test success == :success
end

@testset "LoadingPage - error in handler" begin
    app = App(; loading_page=LoadingPage()) do session
        error("Intentional test error")
    end
    display(edisplay, app)
    Bonito.wait_for_ready(app)

    # Should show error content, not loading page
    success = Bonito.wait_for(timeout=10) do
        # Loading page should be gone (replaced by error)
        evaljs_value(app.session[], js"""
            document.querySelector('.bonito-loading-container') === null
        """)
    end
    @test success == :success
end

@testset "LoadingPage - dom object constructor" begin
    app = App(DOM.div("Static DOM"; class="static-dom"); loading_page=LoadingPage())
    display(edisplay, app)
    Bonito.wait_for_ready(app)

    success = Bonito.wait_for(timeout=10) do
        evaljs_value(app.session[], js"""
            document.querySelector('.static-dom') !== null
        """)
    end
    @test success == :success

    content = evaljs_value(app.session[], js"""
        document.querySelector('.static-dom').textContent
    """)
    @test content == "Static DOM"
end

@testset "LoadingPage - static export with loading_page" begin
    # loading_page with export_static: for NoConnection, falls back to synchronous rendering.
    # For live connections (WebSocket, DualWebsocket), the async Observable update requires
    # a connected session, which export_static doesn't provide. So we only test NoConnection here.
    function loading_page_test_app(session, request)
        result = DOM.div("passed"; dataTestId="lp-result")
        return result
    end

    lp_servers = [
        (:NoServer, () -> NoServer()),
        (:HTTPAssetServer, () -> HTTPAssetServer()),
    ]

    lp_path = joinpath(@__DIR__, "lp_test.html")
    s = Bonito.get_server()
    Bonito.configure_server!(proxy_url="http://localhost:$(s.port)")

    @testset "NoConnection server: $(srv)" for (srv, server) in lp_servers
        app = App(loading_page_test_app; loading_page=LoadingPage())
        session = Session(NoConnection(); asset_server=server())
        sess = export_static(lp_path, app; session=session)
        window = TestWindow(URI("file://" * lp_path))
        result = Bonito.wait_for() do
            run(window, "$(query_testid("lp-result")).innerText") == "passed"
        end
        @test result == :success
        close(window)
        close(app)
    end
    rm(lp_path; force=true)
    Bonito.configure_server!(proxy_url=nothing)
end

@testset "LoadingPage - custom text and spinner" begin
    custom_lp = LoadingPage(text="Custom Loading Message")
    app = App(; loading_page=custom_lp) do session
        sleep(0.5)
        return DOM.div("Done"; class="custom-done")
    end
    display(edisplay, app)
    Bonito.wait_for_ready(app)

    # Check that eventually real content appears
    success = Bonito.wait_for(timeout=15) do
        evaljs_value(app.session[], js"""
            document.querySelector('.custom-done') !== null
        """)
    end
    @test success == :success
end
