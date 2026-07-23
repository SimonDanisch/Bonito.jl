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

function jsrender(session::Session, obs::Observable)
    html = Observable{Any}(
        repr_richest(jsrender(session, obs[]))
    )
    dom = DOM.m_unesc("span", html[])
    on(session, obs) do data
        html[] = by_value(render_sub_session(session, data))
    end
    onjs(session, html, js"(html)=> {
        const new_node = JSServe.materialize_node(html)
        const dom = $(dom)
        dom.replaceChild(new_node, dom.childNodes[0])
    }")
    return dom
end

# on & map versions that deregister when session closes!
function Observables.on(f, session::Session, observable::Observable)
    to_deregister = on(f, observable)
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
