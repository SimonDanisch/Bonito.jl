# styleable_slider_app defined in test_helpers.jl

@testset "StylableSlider" begin
    testsession(styleable_slider_app; port=8555) do app
        dom = app.dom
        a = children(dom)[1]
        @test a.value[] == 1
        @test a.index[] == 1
        b = children(dom)[2]
        @test b.value[] == 2
        @test b.index[] == 2
        c = children(dom)[3]
        @test c.value[] == "b"
        @test c.index[] == 2
    end
end

@testset "Class with observable" begin
    app = App() do session
        class = Observable("no-test")
        evaljs(session, js"""
            $(class).notify("test");
        """)
        DOM.div(DOM.div("HEY HEY"; class=class))
    end
    display(edisplay, app)
    Bonito.wait_for_ready(app)
    success = Bonito.wait_for() do
        class = evaljs_value(app.session[], js"""(()=>{
            const b = document.querySelector(".test");
            if (!b) return "no class";
            return b.className;
        })()""")
        return class == "test"
    end
    @test success == :success
end

# Regression: `update_node_attribute` reached every attribute through its
# reflecting IDL PROPERTY (`node[attribute] = value`). That is required for
# `value`/`checked` — assigning the property is what moves the live state — but
# an attribute with no such property (`data-*`, `aria-*`, any hyphenated custom
# attribute) took the assignment on an EXPANDO instead, leaving the real
# attribute frozen at whatever the first render wrote. Silently: the expando is
# invisible to CSS selectors, to `element.dataset` and to `getAttribute`, and an
# Observable CHILD of the same node kept updating perfectly — so it presented as
# a styling bug, not a binding one.
@testset "data attribute with observable" begin
    app = App() do session
        state = Observable("before")
        evaljs(session, js"""
            $(state).notify("after");
        """)
        DOM.div(DOM.div("HEY HEY"; id="probe", dataState=state, title=state))
    end
    display(edisplay, app)
    Bonito.wait_for_ready(app)
    success = Bonito.wait_for() do
        res = evaljs_value(app.session[], js"""(()=>{
            const b = document.getElementById("probe");
            if (!b) return "no node";
            return JSON.stringify({
                attr: b.getAttribute("data-state"),
                dataset: b.dataset.state,
                title: b.getAttribute("title"),
                // the old code left the new value here instead
                expando: b["data-state"] ?? null,
            });
        })()""")
        res == """{"attr":"after","dataset":"after","title":"after","expando":null}"""
    end
    @test success == :success
end
