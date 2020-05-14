@testset "Observable{DOM}" begin

    obs = Observable(DOM.div("hello"))

    dom_handler(session, request) = DOM.div(obs)

    struct ObsOnload
        obs::Observable{String}
    end

    function JSServe.jsrender(session::Session, t::ObsOnload)
        dom = DOM.div("hey")
        JSServe.evaljs(session, js"""
            console.log(update_obs($(t.obs), "yes!"));
        """)
        return dom
    end
    testsession(dom_handler, port=8555) do app
        t = ObsOnload("aw:(")
        obs[] = DOM.div(t)
        @wait_for t.obs[] == "yes!"
    end

    obs = Observable(DOM.div("hello"))

    dom_handler(session, request) = DOM.div(obs)

    function JSServe.jsrender(session::Session, t::ObsOnload)
        dom = DOM.div("hey")
        JSServe.onload(session, dom, js"""function (div) {
            console.log(update_obs($(t.obs), "yes!"));
        }""")
        return dom
    end

    testsession(dom_handler, port=8555) do app
        t = ObsOnload("aw:(")
        obs[] = DOM.div(t)
        @wait_for t.obs[] == "yes!"
    end

    obs = Observable(DOM.div("hello"))
    dom_handler(session, request) = DOM.div(obs)

    function JSServe.jsrender(session::Session, t::ObsOnload)
        dom = DOM.div("hey")

        JSServe.onload(session, dom, js"""function (div) {
            window.test = "hello";
        }""")

        JSServe.evaljs(session, js"""
        console.log(update_obs($(t.obs), String(window.test == "hello")));
        """)
        return dom
    end

    testsession(dom_handler, port=8555) do app
        t = ObsOnload("aw:(")
        obs[] = DOM.div(t)
        @wait_for t.obs[] == "true"
    end

end

assets(args...) = [joinpath.(@__DIR__, args)...]

@testset "assets on observable dom" begin
    obs = Observable(DOM.div("hello"))
    dom_handler(session, request) = DOM.div(obs)
    JSModule = JSServe.Dependency(:JSModule, assets("test.js", "test.css"))
    test_obs = Observable(0)
    function JSServe.jsrender(session::Session, t::ObsOnload)
        dom = DOM.div("hey")

        JSServe.onload(session, dom, js"""function (div) {
            window.test = "hello";
        }""")

        JSServe.evaljs(session, js"""
            console.log(update_obs($(t.obs), String(window.test == "hello")));
            $(JSModule).testsetter($test_obs);
        """)
        return DOM.div(dom)
    end

    testsession(dom_handler, port=8555) do app
        t = ObsOnload("aw:(")
        obs[] = DOM.div(t)
        @wait_for t.obs[] == "true"
        @test test_obs[] == 2
    end
end
