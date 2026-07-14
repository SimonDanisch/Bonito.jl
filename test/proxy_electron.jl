# Real-browser proof for the session proxy: a host App embeds a worker App via
# `embed_app`; a browser-initiated observable update must travel
# browser → host server → worker (real observables) → back to the browser and
# update the DOM. Uses a hidden (show=false) Electron window, like Bonito's own
# headless tests.

const BONITO = "/sim/Programmieren/ClaudeExperiments/dev/Bonito"
include(joinpath(BONITO, "test", "ElectronTests.jl"))

using Test
using Bonito
using Bonito: App, DOM, Observable, onjs, @js_str, embed_app

electron_evaljs(window, js) = run(window, sprint(show, js))

# Headless, no-focus window (same options Bonito's own runtests.jl uses).
TestWindow(args...; options=Dict{String,Any}("show" => false, "focusOnWebView" => false)) =
    Bonito.EWindow(args...; app=get_test_app(), options=options)

# Worker-side observables kept at module scope so the test knows their ids.
const CLICKS  = Observable(0)
const DOUBLED = map(c -> 2c, CLICKS)

worker_app() = App() do s
    onjs(s, CLICKS, js"(x)=>{}")           # force CLICKS into the cache (prefixed id)
    return DOM.div(DOM.span(DOUBLED; id="result"))
end

const REMOTE = Ref{Any}(nothing)
host_handler = function (session, request)
    r = embed_app(session, worker_app())
    REMOTE[] = r
    return DOM.div(r; id="hostroot")
end

function poll_js(win, js, want; timeout=30)
    t = time() + timeout
    local val
    while time() < t
        val = electron_evaljs(win, js)
        val == want && return true
        sleep(0.05)
    end
    @info "poll_js timed out" js=string(js) last=val want=want
    return false
end

@testset "proxy: real browser round trip" begin
    testsession(host_handler; port=8231) do ts
        wait(ts)
        win = ts.window.window
        r = REMOTE[]
        @test r !== nothing
        prefix = r.render.prefix
        clicks_id = "$(prefix)/$(CLICKS.id)"

        # The embedded worker fragment must mount (proves init_session +
        # fetch_binary of the shipped bundle worked through the host server) and
        # CLICKS must be registered in the browser's global cache under its
        # prefixed id (proves namespacing reached the browser).
        @test poll_js(win, js"document.querySelector('#result') ? 'yes' : 'no'", "yes")
        @test poll_js(win, js"(Bonito.lookup_global_object($(clicks_id)) ? 'yes':'no')", "yes")
        @test electron_evaljs(win, js"document.querySelector('#result').textContent") == "0"

        # Simulate a user interaction: the browser updates CLICKS. This sends an
        # UpdateObservable with the PREFIXED id to the host; the host routes it to
        # the worker, the worker reacts (DOUBLED = 2*CLICKS), and relays the
        # result back — which must update #result in the DOM.
        electron_evaljs(win, js"Bonito.lookup_global_object($(clicks_id)).notify(5)")

        @test poll_js(win, js"document.querySelector('#result').textContent", "10")
        # And the worker's real Julia observable actually holds the value.
        @test CLICKS[] == 5
        @test DOUBLED[] == 10
    end
end
