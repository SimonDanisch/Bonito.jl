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
    # Lock-protected check-then-send so a concurrent
    # jsrender(::Session, ::Observable) listener can't slip a
    # detach_subsession! between our liveness check and our write —
    # which would put a stale UpdateObservable on the wire after the
    # UpdateSession that freed its target on JS.
    try
        lock(deletion_lock(root_session(x.session))) do
            isclosed(x.session) && return
            is_large = value isa LargeUpdate
            data = is_large ? value.data : value
            # String keys (not Symbols) avoid `string(k)` per key inside
            # serialize_cached, hot on every Observable update.
            msg = Dict{String,Any}("payload" => data, "id" => x.id, "msg_type" => UpdateObservable)
            send(x.session, msg; large=is_large)
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
Update the value of an observable, without echoing the change back to the
frontend session that originated it.

`origin` is the session whose browser just pushed this value. We must skip
ONLY that session's `JSUpdateObservable` (so the value doesn't bounce back to
the tab that sent it), but still fire every OTHER session's updater — when two
browser sessions share one observable, session B has to see A's update.
Skipping all `JSUpdateObservable`s (the old behavior) silently desynced them.
All non-`JSUpdateObservable` listeners (user `on`/`map`) always fire.
"""
function update_nocycle!(obs::Observable, @nospecialize(value), origin::Union{Session,Nothing}=nothing)
    obs.val = value
    for (prio, f) in Observables.listeners(obs)
        if f isa JSUpdateObservable
            # Skip only the updater bound to the originating session; let
            # the other sessions' updaters relay the new value onward.
            origin === nothing && continue
            f.session === origin && continue
        end
        started = time_ns()
        try
            Base.invokelatest(f, value)
        finally
            took = (time_ns() - started) / 1e9
            if took >= 0.5
                Base.invokelatest(log_slow_listener, origin, obs.id, f, took)
            end
        end
    end
    return
end

# Keep source lookup and logging off the normal update's inference path. The
# whole-message warning lists every listener; this identifies the slow one.
function log_slow_listener(origin, id, @nospecialize(listener), seconds)
    sites = join(unique(string(basename(string(m.file)), ":", m.line)
                        for m in methods(listener)), ", ")
    page = origin === nothing ? "" : first(root_session(origin).id, 8)
    @warn "slow observable listener" page id seconds = round(seconds; digits = 3) listener = sites
    return nothing
end

# Observables keeps an Observable's listeners in a plain Vector. An Observable
# that outlives one session (a component's state, a chat shared by every tab)
# gets listeners added by one session's render while another session's `free`
# removes its own, on other threads, and the Vector breaks: "Vector can not be
# resized concurrently", or an `UndefRefError` and leaked listeners. Every
# listener a Session adds or removes goes through this one lock. Callbacks never
# run under it.
const LISTENER_LOCK = ReentrantLock()

# on & map versions that deregister when session closes!
function Observables.on(f, session::Session, observable::Observable; update=false)
    to_deregister = lock(LISTENER_LOCK) do
        o = on(f, observable)
        # If the session already closed (a late render task running after
        # `free(session)` emptied `deregister_callbacks`), nothing will ever
        # deregister this listener — it would leak permanently and keep firing
        # into a dead session. Deregister immediately instead.
        isclosed(session) ? off(o) : push!(session.deregister_callbacks, o)
        o
    end
    update && f(observable[])
    return to_deregister
end

function Observables.onany(f, session::Session, observables::Observable...)
    return lock(LISTENER_LOCK) do
        to_deregister = onany(f, observables...)
        isclosed(session) ? foreach(off, to_deregister) : append!(session.deregister_callbacks, to_deregister)
        to_deregister
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
