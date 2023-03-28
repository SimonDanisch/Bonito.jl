using Electron, JSServe, Test
ENV["JULIA_DEBUG"] = JSServe

function electron_evaljs(window, js)
    js_str = sprint(show, js)
    return run(window, js_str)
end

function test_dom(window)
    # wait for everything to be ready
    electron_evaljs(window, js"""(()=> {
            function test(){
            const elem = document.querySelectorAll('select')
            if (elem && elem.length == 2) {
                return elem
            } else {
                return test()
            }
        }
        test()
    })()
    """)

    electron_evaljs(window, js"document.querySelectorAll('select').length") == 2 || return false
    dropdown1 = js"document.querySelectorAll('select')[0]"
    dropdown2 = js"document.querySelectorAll('select')[1]"

    electron_evaljs(window, js"$(dropdown1).selectedIndex") == 0 || return false
    electron_evaljs(window, js"$(dropdown2).selectedIndex") == 1 || return false

    electron_evaljs(
        window,
        js"(()=> {
        const select = $(dropdown1)
        select.selectedIndex = 1;
        const event = new Event('change');
        select.dispatchEvent(event);
    })()")
    electron_evaljs(
        window,
        js"(()=> {
        const select = $(dropdown2)
        select.selectedIndex = 2;
        const event = new Event('change');
        select.dispatchEvent(event);
    })()")
    return true
    # TODO how to get these observables?
    # @test dropdown1_jl.value[] == "b"
    # @test dropdown2_jl.value[] == "c2"
end

begin
    app = App(threaded=true) do session
        dropdown1 = JSServe.Dropdown(["a", "b", "c"])
        dropdown2 = JSServe.Dropdown(["a2", "b2", "c2"]; index=2)
        img = Asset(joinpath(@__DIR__, "..", "docs", "src", "jupyterlab.png"))
        return DOM.div(dropdown1, dropdown2, img, js"""$(JSServe.JSServeLib).then(console.log)""")
    end;
    server = Server(app, "0.0.0.0", 8888)
    url = URI(online_url(server, "/"))
    nwindows = 4
    windows = Channel{Window}(nwindows)
    for i in 1:nwindows
        put!(windows, Window(Application()))
    end
    # Only use half of the available threads to not block the response because we hogged all threads
    results = asyncmap(1:100) do i
        window = take!(windows)
        load(window, url)
        result = test_dom(window)
        put!(windows, window)
        return result
    end
    @test all(results)
end
