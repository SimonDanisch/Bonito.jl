using Hyperscript
using JSServe, Observables
using JSServe: Application, Session, evaljs, linkjs, update_dom!, div, active_sessions
using JSServe: @js_str, onjs, Button, TextField, Slider, JSString, Dependency, with_session
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
end;

# with_session() do session
#     dom_handler(session, nothing)
# end |> display
#
# pop!(JSServe.global_application[].routes.table)
# JSServe.route!(JSServe.global_application[], "/test") do ctx
#     JSServe.serve_dom(ctx, dom_handler)
# end

app = JSServe.Application(
    dom_handler,
    get(ENV, "WEBIO_SERVER_HOST_URL", "127.0.0.1"),
    parse(Int, get(ENV, "WEBIO_HTTP_PORT", "8081")),
    verbose = false
)
close(app)
