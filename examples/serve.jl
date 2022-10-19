using JSServe, Observables
using JSServe: @js_str, onjs, Button, TextField, Slider, linkjs, Session, App
using JSServe.DOM
using Hyperscript

s2 = Slider(1:100)
app = App() do session::Session
    s1 = Slider(1:100)
    b = Button("hi")
    t = TextField("enter your text")
    on(println, s1.value)
    linkjs(session, s1.value, s2.value)
    test = [1,2,3]
    onjs(session, s1.value, js"(v)=> console.log(v + ' ' + $(test))")
    on(t) do text
        println(text)
    end
    return DOM.div(s1, s2, b, t)
end

function run()
    open("test.html", "w") do io
        p = JSServe.dependency_path("JSServe.bundled.js")
        isfile(p) && rm(p)
        s = Session()
        domy = JSServe.session_dom(s, app)
        show(io, Hyperscript.Pretty(domy))
    end
end
isdefined(Main, :server) && close(server)

server = JSServe.Server(app, "127.0.0.1", 8081)
