using Hyperscript, Markdown, Test
using JSServe, Observables
using JSServe: Session, evaljs, linkjs, update_dom!, div, active_sessions
using JSServe: @js_str, onjs, Button, TextField, Slider, JSString, Dependency, with_session
using JSServe.DOM
using JSServe.HTTP
using Electron, URIParser

global dom
global test_session
global test_observable

function test_handler(session, req)
    global dom, test_session, test_observable
    test_session = session

    s1 = Slider(1:100)
    s2 = Slider(1:100)
    b = Button("hi")
    t = TextField("Write!")

    test_observable = Observable(Dict{String, Any}())
    linkjs(session, s1.value, s2.value)

    onjs(session, s1.value, js"(v)=> update_obs($(test_observable), {onjs: v})")

    on(t) do value
        test_observable[] = Dict{String, Any}("textfield" => value)
    end

    on(b) do value
        test_observable[] = Dict{String, Any}("button" => value)
    end

    dom = md"""
    # IS THIS REAL?

    My first slider: $(s1)

    My second slider: $(s2)

    Test: $(s1.value)

    The BUTTON: $(b)

    Type something for the list: $(t)

    some list $(t.value)
    """
    return dom
end

# inline session for a little bit less writing!
function runjs(js)
    JSServe.evaljs_value(test_session, js)
end

http_app = JSServe.Application(test_handler, "127.0.0.1", 8081, verbose=true)
# JSServe.start(app, verbose=true)

response = HTTP.get("http://127.0.0.1:8081/")
@test response.status == 200
close(http_app)
# First get after close will still go through, see: https://github.com/JuliaWeb/HTTP.jl/pull/494
HTTP.get("http://127.0.0.1:8081/", readtimeout=3, retries=1)

connection_refused = try
    x = HTTP.get("http://127.0.0.1:8081/", readtimeout=3, retries=1)
    false
catch e
    e isa HTTP.IOExtras.IOError && e.e == Base.IOError("connect: connection refused (ECONNREFUSED)", -4078)
end

JSServe.start(http_app)
response = HTTP.get("http://127.0.0.1:8081/")
@test response.status == 200

app = Electron.Application()
local_url = URI("http://localhost:8081")
win = Window(app, URI("http://localhost:8081"))
wait(test_session.js_fully_loaded)

@test runjs(js"document.getElementById('application-dom').children.length") == 1
@test runjs(js"document.getElementById('application-dom').children[0].children[0].innerText") == "IS THIS REAL?"
@test runjs(js"document.querySelectorAll('input[type=\"button\"]').length") == 1
@test runjs(js"document.querySelectorAll('input[type=\"range\"]').length") == 2
@test runjs(js"document.querySelectorAll('input[type=\"textfield\"]').length") == 1

@test runjs(js"document.querySelectorAll('input[type=\"button\"]').length") == 1
