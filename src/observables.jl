"""
Functor to update JS part when an observable changes.
We make this a Functor, so we can clearly identify it and don't sent
any updates, if the JS side requires to update an Observable
(so we don't get an endless update cycle)
"""
struct JSUpdateObservable
    session::Session
    id::String
end

# Somehow, showing JSUpdateObservable end up in a stackoverflow...
# Not sure why, but hey, overloading show isn't a bad idea anyways, isn't it?
function Base.show(io::IO, up::JSUpdateObservable)
    print(io, "JSUpdateObservable($(typeof(up.session)), $(repr(up.id)))")
end

function (x::JSUpdateObservable)(value)
    # Sent an update event
    send(x.session, payload=value, id=x.id, msg_type=UpdateObservable)
end

"""
Update the value of an observable, without sending changes to the JS frontend.
This will be used to update updates from the forntend.
"""
function update_nocycle!(obs::Observable, @nospecialize(value))
    obs.val = value
    for (prio, f) in Observables.listeners(obs)
        if !(f isa JSUpdateObservable)
            Base.invokelatest(f, value)
        end
    end
    return
end

# on & map versions that deregister when session closes!
function Observables.on(f, session::Session, observable::Observable; update=false)
    to_deregister = on(f, observable; update=update)
    push!(session.deregister_callbacks, to_deregister)
    return to_deregister
end

function Observables.onany(f, session::Session, observables::Observable...)
    to_deregister = onany(f, observables...)
    append!(session.deregister_callbacks, to_deregister)
    return to_deregister
end

function Base.map(f, session::Session, observables::Observable...; result=Observable{Any}())
    # map guarantees to be run upfront!
    result[] = f(Observables.to_value.(observables)...)
    onany(session, observables...) do newvals...
        result[] = f(newvals...)
    end
    return result
end

render_subsession(p::Session, data::Union{AbstractString, Number}) = (p, DOM.span(string(data)))

function render_subsession(parent::Session, app::App)
    sub = Session(parent)
    return sub, session_dom(sub, app; init=false)
end

function render_subsession(parent::Session, dom::Node)
    render_subsession(parent, App(()-> dom))
end

function update_session_dom!(parent::Session, root_node, data)
    sub, html = render_subsession(parent, data)
    message = Dict(
        :messages => fused_messages!(sub),
        :html => html,
    )
    b64str = serialize_string(sub, message)

    evaljs(parent, js"""
        function callback(dom) {
            const b64str = $(b64str)
            function callback() {
                return JSServe.decode_base64_message(b64str).then(message => {
                    const { messages, html } = message;
                    const dom = $(root_node)
                    console.log(dom.childNodes[dom.childNodes.length-1])
                    dom.replaceChild(html, dom.childNodes[dom.childNodes.length-1])
                    JSServe.process_message(messages)
                    console.log("obs session done: " + $(sub.id))
                })
            }
            JSServe.init_session($(sub.id), callback, 'obs-sub')
        }
        JSServe.on_node_available(callback, $(uuid(root_node)))
    """)
end

function jsrender(session::Session, obs::Observable)
    root_node = DOM.span(DOM.div())
    on(session, obs; update=true) do data
        update_session_dom!(root_session(session), root_node, data)
    end
    return root_node
end
