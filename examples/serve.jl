using JSServe, Observables
using JSServe: @js_str, onjs, Button, TextField, Slider, linkjs
using JSServe.DOM

function dom_handler(session, request)
    s1 = Slider(1:100)
    s2 = Slider(1:100)
    b = Button("hi")
    t = TextField("lol")
    s_value = s1.value
    linkjs(session, s1.value, s2.value)
    onjs(session, s1.value, js"(v)=> console.log(v)")
    on(t) do text
        println(text)
    end
    return DOM.div(s1, s2, b, t)
end

app = JSServe.Application(
    dom_handler,
    "127.0.0.1", 8081, verbose = false
)
# close(app)
