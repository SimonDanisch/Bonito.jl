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

@inline function Base.map!(@nospecialize(f), session::Session, result::AbstractObservable, os...; update::Bool=true)
    # note: the @inline prevents de-specialization due to the splatting
    callback = Observables.MapCallback(f, result, os)
    for o in os
        o isa AbstractObservable && on(callback, session, o)
    end
    update && callback(nothing)
    return result
end

@inline function Base.map(f::F, session::Session, arg1::AbstractObservable, args...; ignore_equal_values=false) where {F}
    # note: the @inline prevents de-specialization due to the splatting
    obs = Observable(f(arg1[], map(Observables.to_value, args)...); ignore_equal_values=ignore_equal_values)
    map!(f, session, obs, arg1, args...; update=false)
    return obs
end

function jsrender(session::Session, obs::Observable)
    root_node = DOM.span()
    on(session, obs) do data
        update_session_dom!(root_session(session), root_node, data; replace=false)
    end
    sub, html = render_subsession(session, obs[])
    push!(children(root_node), html)
    return jsrender(session, root_node)
end
