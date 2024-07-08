
function electron_evaljs(window, js)
    js_str = sprint(show, js)
    return run(window, js_str)
end

function is_fully_loaded(window)
    return electron_evaljs(window, js"""(()=> {
        if (window.js_websocket_isopen && window.js_websocket_isopen()){
            const elem = document.querySelectorAll('select')
            if (elem && elem.length == 2) {
                return true
            }
        }
        return false
    })()
    """)
end

function test_dom(window)
    # wait for everything to be ready
    while !is_fully_loaded(window)
        sleep(0.01)
    end
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


@testset "stresstest threading" begin
    app = App(threaded=true) do session
        dropdown1 = Bonito.Dropdown(["a", "b", "c"])
        dropdown2 = Bonito.Dropdown(["a2", "b2", "c2"]; index=2)
        img = Asset(joinpath(@__DIR__, "..", "docs", "src", "jupyterlab.png"))
        return DOM.div(dropdown1, dropdown2, img, js"""$(Bonito.BonitoLib).then(console.log)""")
    end
    server = Server(app, "0.0.0.0", 8888)

    nwindows = 4
    all_windows = Channel{Window}(nwindows)
    created_windows = Window[]
    for i in 1:nwindows
        win = Window(Application())
        put!(all_windows, win)
        push!(created_windows, win)
    end
    url = URI(online_url(server, "/"))
    # Only use half of the available threads to not block the response because we hogged all threads
    results = asyncmap(1:100) do i
        window = take!(all_windows)
        try
            load(window, url)
            return test_dom(window)
        finally
            put!(all_windows, window)
        end
    end
    @test all(results)
    # It would be nice to close all opened windows, but somehow that seems to hang....
    for win in created_windows
        close(win)
    end
    empty!(created_windows)
    success = Bonito.wait_for(() -> isempty(server.websocket_routes.table), timeout=10)
    @test success == :success
    close(server)
end
