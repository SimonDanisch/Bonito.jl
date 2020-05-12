@testset "Observable{DOM}" begin

    obs = Observable(DOM.div("hello"))

    function dom_handler(session, request)
        return DOM.div(obs)
    end

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
end
