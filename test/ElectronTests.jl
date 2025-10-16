using Electron, JSServe, URIParser
using JSServe.HTTP: Request
using JSServe: Session, Dependency, @js_str, JSCode
import JSServe: start, evaljs, evaljs_value
using JSServe.Hyperscript: Node, HTMLSVG
using JSServe.DOM
using Base: RefValue
using Test

"""
Our Javascript library, defining a few JS helper functions!
"""
const JSTest = Dependency(:Test, [joinpath(@__DIR__, "Test.js")])

"""
    TestSession(handler)

Main construct, which will lunch an electron browser session, serving the application
created by `handler(testsession)::DOM.div`.
Can be used via the testsession function:
```julia
testsession(handler; url="0.0.0.0", port=8081, timeout=300)) do testsession
    # test code using testsession
end
```
This will ensure proper setup and teardown once done with the tests.
The testsession object allows to communicate with the browser session, run javascript
and get values from the html dom!
"""
mutable struct TestSession
    url::URI
    initialized::Bool
    error_in_handler::Any
    server::JSServe.Server
    window::Electron.Window
    session::Session
    dom::Node{HTMLSVG}
    request::Request

    function TestSession(url::URI)
        return new(url, false, nothing)
    end

    function TestSession(url::URI, server::JSServe.Server, window::Electron.Window, session::Session)
        testsession = new(url, true, nothing, server, window, session)
        return testsession
    end
end

JSServe.session(testsession::TestSession) = testsession.session

function Base.show(io::IO, testsession::TestSession)
    print(io, "TestSession")
end

function check_and_close_display()
    # For some reason, when running code in Atom, it happens very easily,
    # That JSServe display server gets started!
    # Maybe better to PR an option in JSServe to prohibit starting it in the first place
    if isassigned(JSServe.GLOBAL_SERVER) && JSServe.isrunning(JSServe.GLOBAL_SERVER[])
        @warn "closing JSServe display server, which interfers with testing!"
        close(JSServe.GLOBAL_SERVER[])
    end
end

function TestSession(handler; url="0.0.0.0", port=8081, timeout=300)
    check_and_close_display()
    testsession = TestSession(URI(string("http://localhost:", port)))
    testsession.server = JSServe.Server(url, port) do session, request
        try
            dom = handler(session, request)
            testsession.dom = dom
            testsession.session = session
            testsession.request = request
            return DOM.div(JSTest, dom)
        catch e
            testsession.error_in_handler = (e, Base.catch_backtrace())
        end
    end
    try
        start(testsession; timeout=timeout)
        return testsession
    catch e
        close(testsession)
        rethrow(e)
    end
end

"""
```julia
    testsession(f, handler; url="0.0.0.0", port=8081, timeout=300)

testsession(handler; url="0.0.0.0", port=8081, timeout=300)) do testsession
    # test code using testsession
end
```
This function will ensure proper setup and teardown once done with the tests or whenever an error occurs.
The testsession object passed to `f` allows to communicate with the browser session, run javascript
and get values from the html dom!
"""
function testsession(f, handler; kw...)
    testsession = TestSession(handler; kw...)
    try
        f(testsession)
    catch e
        rethrow(e)
    finally
        close(testsession)
    end
end

function testsession(handler; kw...)
    return TestSession(handler; kw...)
end

"""
    wait(testsession::TestSession; timeout=300)

Wait for testsession to be fully loaded!
Note, if you call wait on a fully loaded test
"""
function wait(testsession::TestSession; timeout=300)
    testsession.initialized && return true
    if !testsession.window.exists
        error("Window isn't open, can't wait for testsession to be initialized")
    end
    Electron.toggle_devtools(testsession.window)
    while testsession.window.exists
        # We done!
        isdefined(testsession, :session) && isopen(testsession.session) && break
        if testsession.error_in_handler !== nothing
            e, backtrace = testsession.error_in_handler
            Base.show_backtrace(stderr, backtrace)
            throw(e)
        end
        # Again, we need to sleep instead of just waiting on `take!`
        # But if we don't do this, on an error in serving, we'd wait indefinitely
        # even if the window gets closed...And since Julia can't deal with interrupting
        # Wait, that'd mean killing Julia completely
        yield()
    end
    if !isopen(testsession.session)
        error("Window closed before getting a message from serving request")
    end
    on_timeout = "Timed out when waiting for JS to being loaded! Likely an error happend on the JS side, or your testsession is taking longer than $(timeout) seconds. If no error in console, try increasing timeout!"
    tstart = time()
    while time() - tstart < timeout
        if isready(testsession.session.js_fully_loaded)
            # Error on js during init! We can't continue like this :'(
            if testsession.session.init_error[] !== nothing
                throw(testsession.session.init_error[])
            end
            break
        end
        sleep(0.01)
    end
    testsession.initialized = true
    return true
end

"""
    reload!(testsession::TestSession)

Reloads the served application and waits untill all state is initialized.
"""
function reload!(testsession::TestSession; timeout=300)
    check_and_close_display()
    testsession.initialized = true # we need to put it to true, otherwise handler will block!
    # Make 100% sure we're serving something, since otherwise, well block forever
    @assert JSServe.isrunning(testsession.server)
    # Extra long time out for compilation!
    response = JSServe.HTTP.get(string(testsession.url), readtimeout=500)
    @assert response.status == 200
    testsession.initialized = false
    testsession.error_in_handler = nothing
    Electron.load(testsession.window, testsession.url)
    wait(testsession; timeout=timeout)
    @assert testsession.initialized
    return true
end

"""
    start(testsession::TestSession)

Start the testsession and make sure everything is loaded correctly.
Will close all connections, if any error occurs!
"""
function JSServe.start(testsession::TestSession; timeout=300)
    check_and_close_display()
    try
        if !JSServe.isrunning(testsession.server)
            start(testsession.server)
        end
        if !isdefined(testsession, :window) || !testsession.window.exists
            testsession.window = Window()
        end
        reload!(testsession; timeout=timeout)
    catch e
        close(testsession)
        rethrow(e)
    end
    return true
end

"""
    close(testsession::TestSession)

Close the testsession and clean up the state!
"""
function Base.close(testsession::TestSession)
    if isdefined(testsession, :server)
        close(testsession.server)
    end

    if isdefined(testsession, :window)
        # testsession.window.app.exists && close(testsession.window.app)
        testsession.window.exists && close(testsession.window)
    end

    testsession.initialized = false
end

"""
    evaljs(testsession::TestSession, js::JSCode)
Runs javascript code `js` in testsession.
Will return the return value of `js`. Might return garbage data, if return value
isn't json serializable.

Example:
```julia
evaljs(testsession, js"document.getElementById('the-id')")
```
"""
function evaljs(testsession::TestSession, js::JSCode)
    JSServe.evaljs_value(testsession.session, js)
end

"""
    wait_test(condition)
Waits for condition expression to become true and then tests it!
"""
macro wait_for(condition, timeout=5)
    return quote
        tstart = time()
        while !$(esc(condition)) && (time() - tstart) < $(timeout)
            sleep(0.001)
        end
        @test $(esc(condition))
    end
end

"""
    trigger_keyboard_press(testsession::TestSession, code::String, element=nothing)
Triggers a keyboard press on `element`! If element is `nothing`, the event will be
triggered for the whole `document`!
Find out the key code string to pass at `http://keycode.info/`
"""
function trigger_keyboard_press(testsession::TestSession, code::String, element=nothing)
    JSTest.trigger_keyboard_press(testsession.session, code, element)
end

"""
    trigger_mouse_move(testsession::TestSession, code::String, position::Tuple{Int, Int}, element=nothing)
Triggers a MouseMove event! If element == nothing, it will try to trigger on any canvas element
found in the DOM.
"""
function trigger_mouse_move(testsession::TestSession, position::Tuple{Int, Int}, element=nothing)
    JSTest.trigger_mouse_move(testsession.session, position, element)
end

"""
    query_testid(id::String)
Returns a js string, that queries for `id`.
"""
function query_testid(id::String)
    query_str = "[data-test-id=$(repr(id))]"
    js"document.querySelector($(query_str))"
end

"""
    query_testid(testsession::TestSession, id::String)
Returns a JSObject representing the object found for `id`.
"""
function query_testid(testsession::TestSession, id::String)
    return evaljs_value(testsession, query_testid(id))
end
