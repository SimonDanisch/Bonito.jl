using Hyperscript, Markdown
using JSServe, Observables
using JSServe: Application, Session, evaljs, linkjs, update_dom!, div, active_sessions
using JSServe: @js_str, onjs, Button, TextField, Slider, JSString, Dependency, with_session
using JSServe.DOM

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
    # scene = scatter(
    #     1:100, rand(100) .* 100,
    #     markersize = s1, axis = (names = (title = t,),)
    # )
    return md = md"""
    # IS THIS REAL?

    My first slider: $(s1)

    My second slider: $(s2)

    Test: $(s1.value)

    The BUTTON: $(b)

    Type something for the list: $(t)

    some list $(t.value)
    """
end
s = Session()
x = d.dom_function(s, nothing);
JSServe.jsrender(s, x)
s.message_queue
(id, (reg, observable)) = first(s.observables)
observable
JSServe.serialize_string(js"    registered_observables[$(observable)] = $(observable[]);")
using MsgPack, Base64
str = MsgPack.pack(observable[]) |> Base64.base64encode
Base64.base64decode(str) |> MsgPack.unpack
MsgPack.unpack("")
registered_observables['ob_895'] = (decode_base64_msgpack("AQ=="))
;
