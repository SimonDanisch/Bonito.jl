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

struct LargeUpdate
    data::Any
end

function (x::JSUpdateObservable)(@nospecialize(value))
    # Serialize and send before a concurrent teardown can remove the owner.
    try
        lock(deletion_lock(root_session(x.session))) do
            isclosed(x.session) && return
            is_large = value isa LargeUpdate
            data = is_large ? value.data : value
            # String keys (not Symbols) avoid `string(k)` per key inside
            # serialize_cached, hot on every Observable update.
            msg = Dict{String,Any}("payload" => data, "id" => x.id, "msg_type" => UpdateObservable)
            entry = get(x.session.session_objects, x.id, nothing)
            entry === nothing && return
            # Payload objects must be freed with an owner, not kept by the sender.
            message = SerializedMessage(first(entry.owners), msg)
            if !any(sends_in_order, entry.owners)
                register_owners!(message.cache, x.id, entry, SerializedObservable(x.id, nothing))
            end
            send(x.session, message; large=is_large)
        end
    catch e
        # Don't swallow real failures at @debug — a serialization/pack error
        # here means the frontend silently stops updating. Record it on
        # the session (surfaces via the connection indicator + `isready`) and
        # log at @error with a backtrace so it's diagnosable.
        @error "Error while sending update for JSUpdateObservable" exception=(e, catch_backtrace())
        isclosed(x.session) || record_session_error!(x.session, e)
    end
end


"""
Apply a browser update and notify Julia listeners without echoing it to JavaScript.
"""
function update_nocycle!(obs::Observable, @nospecialize(value), session::Union{Session,Nothing}=nothing)
    snapshot() = begin
        obs.val = value
        copy(Observables.listeners(obs))
    end
    callbacks = session === nothing ? snapshot() : lock(snapshot, deletion_lock(session))
    for (prio, f) in callbacks
        f isa JSUpdateObservable && continue
        Base.invokelatest(f, value)
    end
    return
end

# on & map versions that deregister when session closes!
function Observables.on(f, session::Session, observable::Observable; update=false)
    to_deregister = lock(deletion_lock(session)) do
        listener = on(f, observable)
        isclosed(session) ? off(listener) : push!(session.deregister_callbacks, listener)
        return listener
    end
    update && f(observable[])
    return to_deregister
end

function Observables.onany(f, session::Session, observables::Observable...)
    return lock(deletion_lock(session)) do
        listeners = onany(f, observables...)
        isclosed(session) ? foreach(off, listeners) : append!(session.deregister_callbacks, listeners)
        return listeners
    end
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
    # display:contents makes this wrapper transparent to flex/grid layout —
    # the rendered content effectively becomes a child of the user's container.
    # The element still exists in the DOM tree (Bonito uses it as the swap
    # anchor via uuid lookup), it just doesn't generate a CSS box.
    root_node = DOM.div(; style="display:contents")
    prev_sub, html = render_subsession(session, obs[]; init=true)
    mark_displayed!(prev_sub)
    # Double-buffer: keep the previous sub alive across one render so an
    # in-flight asset fetch (e.g. a threejs ES6 module) still resolves
    # against a live `ChildAssetServer`. The older sub (two renders back)
    # closes when the next render arrives.
    older_sub = nothing
    on(session, obs) do data
        # Atomic displacement: hold deletion_lock across update_session_dom!
        # AND detach so a concurrent JSUpdateObservable (which also takes
        # the lock) either runs before this body — its send is on the wire
        # before the new UpdateSession — or after detach, sees status=CLOSED
        # on prev_sub, and bails. Without the lock a stale UpdateObservable
        # can land on JS after the UpdateSession that freed its target.
        lock(deletion_lock(root_session(session))) do
            # close may have taken the lock while this notify was already in
            # flight, and the `off` in `free` can't cancel an in-flight
            # listener. The DOM is gone with the session, so bail quietly;
            # update_session_dom! keeps its loud error for real misuse.
            isclosed(session) && return
            new_sub = update_session_dom!(session, uuid(session, root_node), data; replace=false)
            if new_sub !== prev_sub
                older_sub !== nothing && close(older_sub)
                # Detach the just-displaced sub: its DOM is gone on JS
                # (update_or_replace cleared the wrapper), so any of its
                # reactive bindings still firing would target removed nodes
                # ("Cannot set properties of null" / "Timeout waiting for
                # DOM node"). asset_server stays alive; full close happens
                # one render later when prev_sub is displaced from older_sub.
                detach_subsession!(prev_sub)
                older_sub = prev_sub
                prev_sub = new_sub
            end
        end
        return
    end
    # When the parent session itself closes, drop both held subs. Listener
    # exceptions are swallowed in close, but we keep handles separate so
    # GC reclaims immediately.
    on(session.on_close) do _
        older_sub !== nothing && close(older_sub)
        prev_sub !== nothing && close(prev_sub)
        return
    end
    push!(children(root_node), html)
    return jsrender(session, root_node)
end

# Fast path for simple types
function jsrender(session::Session, obs::Observable{T}) where {T <: Union{Number, String, Symbol}}
    root_node = DOM.span(string(obs[]))
    obs_js = map(string, session, obs)
    onjs(
        session,
        obs_js,
        js"""(val)=> {
            $(root_node).innerText = val
        }"""
    )
    return root_node
end


function jsrender(session::Session, obs::Observable{<:HTML})
    root_node = DOM.span(obs[])
    onjs(
        session,
        obs,
        js"""(val)=> {
            $(root_node).replaceChildren(val);
        }"""
    )
    return root_node
end
