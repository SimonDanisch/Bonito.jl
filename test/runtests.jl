using Hyperscript
using JSServe, Observables
using JSServe: Application, Session, evaljs, linkjs, update_dom!, div, active_sessions
using JSServe: @js_str, font, onjs, Button, TextField, Slider, JSString, Dependency, with_session

d = with_session() do session
    s1 = Slider(1:100)
    s2 = Slider(1:100)
    b = Button("hi")
    t = TextField("lol")
    linkjs(session, s1.value, s2.value)
    onjs(session, s1.value, js"(v)=> console.log(v)")
    on(t) do text
        println(text)
    end
    return JSServe.div(s1, s2, b, t)
end
