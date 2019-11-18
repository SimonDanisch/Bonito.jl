using Hyperscript, Markdown
using JSServe, Observables
using JSServe: Application, Session, evaljs, linkjs, update_dom!, div, active_sessions
using JSServe: @js_str, onjs, Button, TextField, Slider, JSString, Dependency, with_session
using JSServe.DOM
# using AbstractPlotting, WGLMakie


function test_handler(session, req)
    s1 = Slider(1:100)
    s2 = Slider(1:100)
    b = Button("hi")
    t = TextField("Write!")
    linkjs(session, s1.value, s2.value)
    onjs(session, s1.value, js"(v)=> console.log(v)")
    on(t) do text
        println(text)
    end
    # scene = scatter(
    #     1:100, rand(100) .* 100,
    #     markersize = s1, axis = (names = (title = t,),)
    # )
    return md = md"""
    My first slider: $(s1)

    My second slider: $(s2)

    Test: $(s1.value)

    The BUTTON: $(b)

    Type something for the list: $(t)

    some list $(t.value)

    # Plotting
    """
end

JSServe.DisplayInline(test_handler)

d = with_session() do session, req
    s1 = Slider(1:100)
    s2 = Slider(1:100)
    b = Button("hi")
    t = TextField("Write!")
    linkjs(session, s1.value, s2.value)
    onjs(session, s1.value, js"(v)=> console.log(v)")
    on(t) do text
        println(text)
    end
    scene = scatter(
        1:100, rand(100) .* 100,
        markersize = s1, axis = (names = (title = t,),)
    )
    return md = md"""
    My first slider: $(s1)

    My second slider: $(s2)

    Test: $(s1.value)

    The BUTTON: $(b)

    Type something for the list: $(t)

    some list $(t.value)

    # Plotting
    $scene
    """
end;

d.dom_function(Session(), nothing);
@time display(d)
d










d.sessionid
