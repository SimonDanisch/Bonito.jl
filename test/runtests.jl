using Hyperscript, Markdown
using JSServe, Observables
using JSServe: Application, Session, evaljs, linkjs, update_dom!, div, active_sessions
using JSServe: @js_str, onjs, Button, TextField, Slider, JSString, Dependency, with_session
using JSServe.DOM
using AbstractPlotting, WGLMakie

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
    scene = scatter(1:100, rand(100) .* 100, markersize = s1, axis = (names = (title = t,),))
    return md = md"""
    My first slider: $(s1)

    My second slider: $(s2)

    Test: $(s1.value)

    The BUTTON: $(b)

    Type something for the list: $(t)

    some list $(t.value)

    # Plotting

    $(scene)
    """
end
s1 = Slider(1:100)

sess = Session()
s1 = Slider(1:100)
s2 = Slider(1:100)
b = Button("hi")
t = TextField("lol")
linkjs(sess, s1.value, s2.value)
onjs(sess, s1.value, js"(v)=> console.log(v)")
on(t) do text
    println(text)
end
s1 = Slider(1:100)
md = md"""
$(s1)
Test: $(s1.value)
""";

show(stdout, Hyperscript.Pretty(JSServe.jsrender(sess, md)))

JSServe.jsrender(sess, md)

sess isa JSServe.Session
JSServe.jsrender(sess, md)
dom = with_session() do session
    return JSServe.jsrender(session, md)
end
JSServe.plotpane_pages[dom.sessionid] |> typeof
