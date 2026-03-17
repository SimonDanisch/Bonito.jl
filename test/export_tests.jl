# Tests for offline HTML export (export_static)
# Inspired by BonitoBook.export_html patterns, without depending on BonitoBook.
# Each test exports an App to a standalone HTML file, loads it in an ElectronCall window,
# and verifies the content is correct.

const EXPORT_TEST_DIR = mktempdir()

function export_and_verify(app::App; timeout=10)
    path = joinpath(EXPORT_TEST_DIR, "test_$(randstring(8)).html")
    export_static(path, app)
    window = TestWindow(URI("file://" * path))
    try
        return window, path
    catch
        close(window)
        rethrow()
    end
end

function with_export(f, app::App; timeout=10)
    window, path = export_and_verify(app; timeout=timeout)
    try
        f(window)
    finally
        close(window)
    end
end

# Helper: wait for element and check text
function wait_for_text(window, selector, expected; timeout=10)
    result = Bonito.wait_for(; timeout=timeout) do
        run(window, "document.querySelector('$selector') && document.querySelector('$selector').innerText") == expected
    end
    return result
end

@testset "Static Export" begin

    @testset "basic static DOM" begin
        app = App() do session
            DOM.div(
                DOM.h1("Hello Export"),
                DOM.p("This is a static page"; class="content"),
                dataTestId="root"
            )
        end
        with_export(app) do window
            result = Bonito.wait_for() do
                run(window, "document.querySelector('h1') && document.querySelector('h1').innerText") == "Hello Export"
            end
            @test result == :success
            @test run(window, "document.querySelector('.content').innerText") == "This is a static page"
        end
    end

    @testset "observable text binding" begin
        app = App() do session
            obs = Observable("initial value")
            DOM.div(obs; dataTestId="obs-div")
        end
        with_export(app) do window
            result = Bonito.wait_for() do
                text = run(window, "document.querySelector('[data-test-id=\"obs-div\"]') && document.querySelector('[data-test-id=\"obs-div\"]').innerText")
                text !== nothing && occursin("initial value", string(text))
            end
            @test result == :success
        end
    end

    @testset "observable attribute binding" begin
        app = App() do session
            class_obs = Observable("my-class")
            DOM.div("styled"; class=class_obs, dataTestId="attr-div")
        end
        with_export(app) do window
            result = Bonito.wait_for() do
                run(window, "document.querySelector('.my-class') !== null")
            end
            @test result == :success
        end
    end

    @testset "inline JavaScript execution" begin
        app = App() do session
            result_div = DOM.div("waiting"; dataTestId="js-result")
            script = js"""
                const el = document.querySelector('[data-test-id="js-result"]');
                if (el) el.innerText = "js executed";
            """
            DOM.div(result_div, script)
        end
        with_export(app) do window
            result = Bonito.wait_for() do
                run(window, "document.querySelector('[data-test-id=\"js-result\"]') && document.querySelector('[data-test-id=\"js-result\"]').innerText") == "js executed"
            end
            @test result == :success
        end
    end

    @testset "CSS and Styles" begin
        app = App(; indicator=nothing) do session
            style = Styles(
                "background-color" => "rgb(255, 0, 0)",
                "padding" => "10px",
            )
            DOM.div("Styled content"; style=style, dataTestId="styled")
        end
        with_export(app) do window
            result = Bonito.wait_for() do
                run(window, "document.querySelector('[data-test-id=\"styled\"]') !== null")
            end
            @test result == :success
            bg = run(window, "getComputedStyle(document.querySelector('[data-test-id=\"styled\"]')).backgroundColor")
            @test bg == "rgb(255, 0, 0)"
        end
    end

    @testset "CSS variables and rules" begin
        app = App(; indicator=nothing) do session
            style = Styles(
                CSS(":root", "--test-color" => "rgb(0, 128, 0)"),
                CSS(".test-var", "color" => "var(--test-color)"),
            )
            DOM.div(
                style,
                DOM.div("Green text"; class="test-var", dataTestId="var-styled")
            )
        end
        with_export(app) do window
            result = Bonito.wait_for() do
                run(window, "document.querySelector('.test-var') !== null")
            end
            @test result == :success
            color = run(window, "getComputedStyle(document.querySelector('.test-var')).color")
            @test color == "rgb(0, 128, 0)"
        end
    end

    @testset "nested DOM structure" begin
        app = App() do session
            DOM.div(
                DOM.div(
                    DOM.div(
                        DOM.span("deep nested"; dataTestId="nested")
                    )
                )
            )
        end
        with_export(app) do window
            result = Bonito.wait_for() do
                run(window, "document.querySelector('[data-test-id=\"nested\"]') && document.querySelector('[data-test-id=\"nested\"]').innerText") == "deep nested"
            end
            @test result == :success
        end
    end

    @testset "multiple children" begin
        app = App() do session
            items = [DOM.li("Item $i"; dataTestId="item-$i") for i in 1:5]
            DOM.ul(items...)
        end
        with_export(app) do window
            result = Bonito.wait_for() do
                run(window, "document.querySelectorAll('li').length") == 5
            end
            @test result == :success
            @test run(window, "document.querySelector('[data-test-id=\"item-3\"]').innerText") == "Item 3"
        end
    end

    @testset "slider with record_states" begin
        app = App() do session
            slider = Slider(1:5)
            label = DOM.div(slider.value; dataTestId="slider-label")
            DOM.div(slider, label)
        end
        with_export(app) do window
            result = Bonito.wait_for() do
                run(window, "document.querySelector('input[type=\"range\"]') !== null")
            end
            @test result == :success
            result = Bonito.wait_for() do
                text = run(window, "document.querySelector('[data-test-id=\"slider-label\"]') && document.querySelector('[data-test-id=\"slider-label\"]').innerText")
                text !== nothing && !isempty(string(text))
            end
            @test result == :success
        end
    end

    @testset "checkbox with record_states" begin
        app = App() do session
            cb = Checkbox(true)
            label = DOM.div(cb.value; dataTestId="cb-label")
            DOM.div(cb, label)
        end
        with_export(app) do window
            result = Bonito.wait_for() do
                run(window, "document.querySelector('input[type=\"checkbox\"]') !== null")
            end
            @test result == :success
        end
    end

    @testset "dropdown with record_states" begin
        app = App() do session
            dd = Dropdown(["Apple", "Banana", "Cherry"])
            label = DOM.div(dd.value; dataTestId="dd-label")
            DOM.div(dd, label)
        end
        with_export(app) do window
            result = Bonito.wait_for() do
                run(window, "document.querySelector('select') !== null")
            end
            @test result == :success
            n_options = run(window, "document.querySelector('select').options.length")
            @test n_options == 3
        end
    end

    @testset "ES6Module asset" begin
        # Uses the three.js test module already present in the test directory
        THREE = ES6Module(joinpath(@__DIR__, "three.js"))
        app = App() do session
            result = DOM.div("failed"; dataTestId="es6-result")
            DOM.div(
                result,
                js"""
                    $(THREE).then(three=> {
                        if ('AdditiveAnimationBlendMode' in three) {
                            $(result).innerText = "passed"
                        }
                    });
                """
            )
        end
        with_export(app) do window
            result = Bonito.wait_for(; timeout=15) do
                run(window, "document.querySelector('[data-test-id=\"es6-result\"]') && document.querySelector('[data-test-id=\"es6-result\"]').innerText") == "passed"
            end
            @test result == :success
        end
    end

    @testset "NoServer vs HTTPAssetServer" begin
        s = Bonito.get_server()
        Bonito.configure_server!(proxy_url="http://localhost:$(s.port)")

        servers = [
            (:NoServer, () -> NoServer()),
            (:HTTPAssetServer, () -> HTTPAssetServer()),
        ]

        @testset "asset server: $name" for (name, make_server) in servers
            app = App() do session
                DOM.div("asset test passed"; dataTestId="asset-result")
            end
            path = joinpath(EXPORT_TEST_DIR, "asset_$(name)_$(randstring(4)).html")
            session = Session(NoConnection(); asset_server=make_server())
            export_static(path, app; session=session)
            window = TestWindow(URI("file://" * path))
            result = Bonito.wait_for() do
                run(window, "document.querySelector('[data-test-id=\"asset-result\"]') && document.querySelector('[data-test-id=\"asset-result\"]').innerText") == "asset test passed"
            end
            @test result == :success
            close(window)
        end
        Bonito.configure_server!(proxy_url=nothing)
    end

    @testset "export_mode flag pattern" begin
        # BonitoBook sets window.BONITO_EXPORT_MODE = true in exports
        app = App() do session
            export_script = js"""
                window.BONITO_EXPORT_MODE = true;
                document.body.classList.add('bonito-export-mode');
            """
            DOM.div(
                export_script,
                DOM.div("export mode active"; dataTestId="export-flag")
            )
        end
        with_export(app) do window
            result = Bonito.wait_for() do
                run(window, "window.BONITO_EXPORT_MODE") == true
            end
            @test result == :success
            @test run(window, "document.body.classList.contains('bonito-export-mode')") == true
        end
    end

    @testset "reactive map pattern" begin
        # Pattern used in BonitoBook: map() to derive display from observable
        app = App() do session
            value = Observable(42)
            display_text = map(v -> "Value is: $v", value)
            DOM.div(display_text; dataTestId="mapped")
        end
        with_export(app) do window
            result = Bonito.wait_for() do
                text = run(window, "document.querySelector('[data-test-id=\"mapped\"]') && document.querySelector('[data-test-id=\"mapped\"]').innerText")
                text !== nothing && occursin("Value is: 42", string(text))
            end
            @test result == :success
        end
    end

    @testset "multiple widgets in one export" begin
        app = App() do session
            slider = Slider(1:10)
            checkbox = Checkbox(false)
            dropdown = Dropdown(["x", "y", "z"])
            DOM.div(
                DOM.div(slider; dataTestId="w-slider"),
                DOM.div(checkbox; dataTestId="w-checkbox"),
                DOM.div(dropdown; dataTestId="w-dropdown"),
            )
        end
        with_export(app) do window
            result = Bonito.wait_for() do
                run(window, "document.querySelector('input[type=\"range\"]') !== null") &&
                run(window, "document.querySelector('input[type=\"checkbox\"]') !== null") &&
                run(window, "document.querySelector('select') !== null")
            end
            @test result == :success
        end
    end

    @testset "LoadingPage in static export" begin
        app = App(; loading_page=LoadingPage()) do session
            DOM.div("loaded content"; dataTestId="lp-export")
        end
        with_export(app) do window
            result = Bonito.wait_for() do
                run(window, "document.querySelector('[data-test-id=\"lp-export\"]') && document.querySelector('[data-test-id=\"lp-export\"]').innerText") == "loaded content"
            end
            @test result == :success
        end
    end

    @testset "markdown content in export" begin
        app = App() do session
            md_content = md"""
            # Heading

            Some **bold** and *italic* text.
            """
            DOM.div(DOM.div(md_content), DOM.div("md done"; dataTestId="md-test"))
        end
        with_export(app) do window
            result = Bonito.wait_for() do
                run(window, "document.querySelector('[data-test-id=\"md-test\"]') && document.querySelector('[data-test-id=\"md-test\"]').innerText") == "md done"
            end
            @test result == :success
            @test run(window, "document.querySelector('h1') !== null") == true
        end
    end

    @testset "onclick handler in export" begin
        app = App() do session
            counter = Observable(0)
            btn = DOM.button("Click me";
                onclick=js"$(counter).notify($(counter).value + 1)",
                dataTestId="click-btn"
            )
            label = DOM.div(counter; dataTestId="click-count")
            DOM.div(btn, label)
        end
        with_export(app) do window
            result = Bonito.wait_for() do
                run(window, "document.querySelector('[data-test-id=\"click-btn\"]') !== null")
            end
            @test result == :success
        end
    end

    @testset "data-* attributes preserved" begin
        app = App() do session
            DOM.div("data attrs";
                dataTestId="data-test",
                dataCustom="custom-value",
                dataIndex="42"
            )
        end
        with_export(app) do window
            result = Bonito.wait_for() do
                run(window, "document.querySelector('[data-test-id=\"data-test\"]') !== null")
            end
            @test result == :success
            @test run(window, "document.querySelector('[data-test-id=\"data-test\"]').dataset.custom") == "custom-value"
            @test run(window, "document.querySelector('[data-test-id=\"data-test\"]').dataset.index") == "42"
        end
    end

    @testset "nested observable session + onjs + onclick" begin
        # Regression test: Observable(DOM.div()) creates a nested session.
        # An observable used in onclick must still be findable on JS side,
        # even when rendered after the nested session.
        app = App() do session
            click_obs = Observable(false)
            onjs(session, click_obs, js"""(v) => {
                document.querySelector('[data-test-id="onjs-out"]').innerText = "onjs:" + v;
            }""")
            div_obs = Observable(DOM.div("nested content"; dataTestId="nested-div"))
            btn = DOM.button(
                onclick = js"""() => { $(click_obs).notify(true); }""",
                "Click"; dataTestId="nested-btn")
            onjs_out = DOM.div("waiting"; dataTestId="onjs-out")
            DOM.div(div_obs, btn, onjs_out)
        end
        with_export(app) do window
            # Nested content rendered
            result = Bonito.wait_for() do
                run(window, """(function(){
                    var el = document.querySelector('[data-test-id="nested-div"]');
                    return el ? el.innerText : null;
                })()""") == "nested content"
            end
            @test result == :success
            # Button exists
            @test run(window, "document.querySelector('[data-test-id=\"nested-btn\"]') !== null") == true
            # Click triggers onjs
            run(window, "document.querySelector('[data-test-id=\"nested-btn\"]').click()")
            result = Bonito.wait_for() do
                run(window, "document.querySelector('[data-test-id=\"onjs-out\"]').innerText") == "onjs:true"
            end
            @test result == :success
        end
    end

    @testset "observable in content vs attribute vs JS callback" begin
        # Test that observables work regardless of where they're inserted:
        # 1. As DOM content: DOM.div(obs)
        # 2. As an attribute: DOM.div(; class=obs)
        # 3. In a JS callback: onclick=js"$(obs).notify(...)"
        app = App() do session
            text_obs = Observable("text-value")
            class_obs = Observable("class-value")
            js_obs = Observable(0)
            onjs(session, js_obs, js"""(v) => {
                document.querySelector('[data-test-id="js-triggered"]').innerText = "js:" + v;
            }""")
            DOM.div(
                DOM.div(text_obs; dataTestId="obs-as-content"),
                DOM.div("attr-test"; class=class_obs, dataTestId="obs-as-attr"),
                DOM.button(onclick=js"""() => { $(js_obs).notify(42); }"""; dataTestId="obs-in-js"),
                DOM.div("init"; dataTestId="js-triggered"),
            )
        end
        with_export(app) do window
            # Content binding
            result = Bonito.wait_for() do
                t = run(window, "document.querySelector('[data-test-id=\"obs-as-content\"]')?.innerText")
                t !== nothing && occursin("text-value", string(t))
            end
            @test result == :success
            # Attribute binding
            @test run(window, "document.querySelector('[data-test-id=\"obs-as-attr\"]').className.includes('class-value')") == true
            # JS callback binding
            run(window, "document.querySelector('[data-test-id=\"obs-in-js\"]').click()")
            result = Bonito.wait_for() do
                run(window, "document.querySelector('[data-test-id=\"js-triggered\"]').innerText") == "js:42"
            end
            @test result == :success
        end
    end

    @testset "deeply nested observables" begin
        # Multiple levels of Observable nesting
        app = App() do session
            inner_obs = Observable("inner")
            outer_obs = Observable(DOM.div(
                DOM.div(inner_obs; dataTestId="deep-inner"),
                dataTestId="deep-outer"
            ))
            DOM.div(outer_obs; dataTestId="deep-root")
        end
        with_export(app) do window
            result = Bonito.wait_for() do
                run(window, "document.querySelector('[data-test-id=\"deep-outer\"]') !== null")
            end
            @test result == :success
            result = Bonito.wait_for() do
                t = run(window, "document.querySelector('[data-test-id=\"deep-inner\"]')?.innerText")
                t !== nothing && occursin("inner", string(t))
            end
            @test result == :success
        end
    end

    @testset "multiple observables in same DOM tree" begin
        # Multiple independent observables that must all resolve correctly
        app = App() do session
            obs1 = Observable("first")
            obs2 = Observable("second")
            obs3 = Observable("third")
            trigger = Observable(0)
            onjs(session, trigger, js"""(v) => {
                document.querySelector('[data-test-id="trigger-out"]').innerText = "t:" + v;
            }""")
            DOM.div(
                DOM.div(obs1; dataTestId="multi-1"),
                DOM.div(obs2; dataTestId="multi-2"),
                DOM.div(obs3; dataTestId="multi-3"),
                DOM.button(onclick=js"""() => { $(trigger).notify(99); }"""; dataTestId="multi-btn"),
                DOM.div("init"; dataTestId="trigger-out"),
            )
        end
        with_export(app) do window
            result = Bonito.wait_for() do
                run(window, "document.querySelector('[data-test-id=\"multi-1\"]') !== null")
            end
            @test result == :success
            t1 = run(window, "document.querySelector('[data-test-id=\"multi-1\"]').innerText")
            t2 = run(window, "document.querySelector('[data-test-id=\"multi-2\"]').innerText")
            t3 = run(window, "document.querySelector('[data-test-id=\"multi-3\"]').innerText")
            @test occursin("first", string(t1))
            @test occursin("second", string(t2))
            @test occursin("third", string(t3))
            # JS callback still works with many observables
            run(window, "document.querySelector('[data-test-id=\"multi-btn\"]').click()")
            result = Bonito.wait_for() do
                run(window, "document.querySelector('[data-test-id=\"trigger-out\"]').innerText") == "t:99"
            end
            @test result == :success
        end
    end

    @testset "nested observable + asset server combinations" begin
        s = Bonito.get_server()
        Bonito.configure_server!(proxy_url="http://localhost:$(s.port)")

        servers = [
            (:NoServer, () -> NoServer()),
            (:HTTPAssetServer, () -> HTTPAssetServer()),
        ]

        @testset "asset server: $name" for (name, make_server) in servers
            app = App() do session
                click_obs = Observable(false)
                onjs(session, click_obs, js"""(v) => {
                    document.querySelector('[data-test-id="as-onjs"]').innerText = "ok:" + v;
                }""")
                div_obs = Observable(DOM.div("nested"; dataTestId="as-nested"))
                btn = DOM.button(
                    onclick = js"""() => { $(click_obs).notify(true); }""";
                    dataTestId="as-btn")
                DOM.div(div_obs, btn, DOM.div("init"; dataTestId="as-onjs"))
            end
            path = joinpath(EXPORT_TEST_DIR, "nested_$(name)_$(randstring(4)).html")
            session = Session(NoConnection(); asset_server=make_server())
            export_static(path, app; session=session)
            window = TestWindow(URI("file://" * path))
            # Nested content
            result = Bonito.wait_for() do
                run(window, """(function(){
                    var el = document.querySelector('[data-test-id="as-nested"]');
                    return el ? el.innerText : null;
                })()""") == "nested"
            end
            @test result == :success
            # onclick + onjs across session boundary
            run(window, "document.querySelector('[data-test-id=\"as-btn\"]').click()")
            result = Bonito.wait_for() do
                run(window, "document.querySelector('[data-test-id=\"as-onjs\"]').innerText") == "ok:true"
            end
            @test result == :success
            close(window)
        end
        Bonito.configure_server!(proxy_url=nothing)
    end

end

# Cleanup
rm(EXPORT_TEST_DIR; recursive=true, force=true)
