using ElectronCall, Bonito
using Bonito.HTTP: Request
import Bonito.HTTPServer: start, isrunning
using Bonito: Session, @js_str, JSCode
import Bonito: evaljs, evaljs_value
using Bonito.Hyperscript: Node, HTMLSVG
using Bonito.DOM
using Base: RefValue
using Test

# Single shared ElectronCall Application for all tests.
# Creating multiple Applications spawns multiple Electron processes, which is wasteful.
const TEST_APP = Ref{Union{Nothing, ElectronCall.Application}}(nothing)

function get_test_app()
    if TEST_APP[] === nothing || !TEST_APP[].exists
        TEST_APP[] = ElectronCall.Application(;
            additional_electron_args=Bonito.HTTPServer.default_electron_args(),
            security=Bonito.HTTPServer.default_security_config(),
            verbose=false,
        )
    end
    return TEST_APP[]
end

function close_test_app()
    if TEST_APP[] !== nothing && TEST_APP[].exists
        close(TEST_APP[])
    end
    TEST_APP[] = nothing
end

"""
    TestSession(handler)

Main construct, which will launch an electron browser session, serving the application
created by `handler(session, request)::DOM.div`.
Can be used via the testsession function:
```julia
testsession(handler; url="0.0.0.0", port=8081, timeout=300) do testsession
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
    server::Bonito.Server
    window::Bonito.EWindow
    session::Session
    dom::Node{HTMLSVG}
    request::Request

    function TestSession(url::URI)
        return new(url, false, nothing)
    end
end

Bonito.session(testsession::TestSession) = testsession.session

function Base.show(io::IO, testsession::TestSession)
    print(io, "TestSession")
end

function TestSession(handler; url="0.0.0.0", port=8081, timeout=300)
    app = App() do session, request
        try
            dom = handler(session, request)
            testsession.dom = dom
            testsession.session = session
            testsession.request = request
            return dom
        catch e
            testsession.error_in_handler = (e, Base.catch_backtrace())
        end
    end
    server = Bonito.Server(app, url, port)
    testsession = TestSession(URI(string("http://localhost:", server.port)))
    testsession.server = server
    try
        start_testsession!(testsession; timeout=timeout)
        return testsession
    catch e
        close(testsession)
        rethrow(e)
    end
end

"""
    testsession(f, handler; kw...)

Context manager for TestSession. Ensures proper setup and teardown.
```julia
testsession(handler; port=8081) do ts
    # test code using ts
end
```
"""
function testsession(f, handler; kw...)
    ts = TestSession(handler; kw...)
    try
        f(ts)
    finally
        close(ts)
    end
end

function testsession(handler; kw...)
    return TestSession(handler; kw...)
end

"""
    Base.wait(testsession::TestSession; timeout=300)

Wait for testsession to be fully loaded.
"""
function Base.wait(testsession::TestSession; timeout=300)
    testsession.initialized && return true
    if !testsession.window.window.exists
        error("Window isn't open, can't wait for testsession to be initialized")
    end
    while testsession.window.window.exists
        isdefined(testsession, :session) && isopen(testsession.session) && break
        if testsession.error_in_handler !== nothing
            e, backtrace = testsession.error_in_handler
            Base.show_backtrace(stderr, backtrace)
            throw(e)
        end
        yield()
    end
    if !isopen(testsession.session)
        error("Window closed before getting a message from serving request")
    end
    tstart = time()
    while time() - tstart < timeout
        if isready(testsession.session)
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
    reload!(testsession::TestSession; timeout=300)

Reloads the served application and waits until all state is initialized.
"""
function reload!(testsession::TestSession; timeout=300)
    testsession.initialized = true # prevent handler from blocking
    @assert isrunning(testsession.server)
    response = Bonito.HTTP.get(string(testsession.url), readtimeout=500)
    @assert response.status == 200
    testsession.initialized = false
    testsession.error_in_handler = nothing
    ElectronCall.load(testsession.window.window, testsession.url)
    wait(testsession; timeout=timeout)
    @assert testsession.initialized
    return true
end

"""
    start_testsession!(testsession::TestSession; timeout=300)

Start the testsession and make sure everything is loaded correctly.
"""
function start_testsession!(testsession::TestSession; timeout=300)
    try
        if isrunning(testsession.server)
            start(testsession.server)
        end
        if !isdefined(testsession, :window) || !testsession.window.window.exists
            testsession.window = TestWindow()
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

Close the testsession window and server. Does NOT close the shared Application.
"""
function Base.close(testsession::TestSession)
    if isdefined(testsession, :window) && testsession.window.window.exists
        close(testsession.window.window)
    end
    testsession.initialized = false
    if isdefined(testsession, :server)
        close(testsession.server)
    end
end

"""
    evaljs(testsession::TestSession, js::JSCode)

Runs javascript code `js` in testsession and returns the result.
"""
function evaljs(testsession::TestSession, js::JSCode)
    Bonito.evaljs_value(testsession.session, js)
end

"""
    @wait_for(condition, timeout=5)

Waits for condition expression to become true and then tests it.
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
    query_testid(id::String)

Returns a JS expression that queries for an element with `data-test-id=id`.
"""
function query_testid(id::String)
    query_str = "[data-test-id=$(repr(id))]"
    js"document.querySelector($(query_str))"
end

function query_testid(testsession::TestSession, id::String)
    return evaljs_value(testsession, query_testid(id))
end
