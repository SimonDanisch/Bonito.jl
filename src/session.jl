function show_session(io::IO, session::Session{T}) where T
    println(io, "Session{$T}:")
    println(io, "  id: $(session.id)")
    println(io, "  parent: $(typeof(session.parent))")
    println(io, "  status: $(session.status)")
    if !isempty(session.children)
        println(io, "children: $(length(session.children))")
    end
    println(io, "  connection: $(isopen(session.connection) ? "open" : "closed")")
    println(io, "  isready: $(isready(session; throw=false))")
    println(io, "  asset_server: $(typeof(session.asset_server))")
    println(io, "  queued messages: $(length(session.message_queue))")
    if !isnothing(session.init_error[])
        println(io, "  session failed to initialize:")
        showerror(io, session.init_error[])
    end
end

Base.show(io::IO, ::MIME"text/plain", session::Session) = show_session(io, session)
Base.show(io::IO, session::Session) = show_session(io, session)

function wait_for_ready(session::Session; timeout=100)
    session.status === CLOSED && return false
    success = wait_for(timeout=timeout) do
        isclosed(session) && return :closed
        return isready(session)
    end
    return success
end

function init_session(session::Session)
    root = root_session(session)
    # Ordering invariant (F10/B4): the queued setup messages (object
    # registrations + on_document_load) MUST reach the wire BEFORE any later
    # direct `_send`. `_send` gates writes on `isready(session)`, which is
    # `connection_ready` (the one-shot Channel) AND `isopen`. So as long as
    # `connection_ready` is NOT yet signaled, every concurrent `_send` queues
    # rather than writes. We exploit that to keep ordering WITHOUT holding the
    # lock across the (potentially blocking, backpressured) init-bundle socket
    # write (B36): drain + status flip under the lock, write the bundle with
    # the lock RELEASED, then re-acquire and signal `connection_ready` (+ flush
    # anything that queued during the write). The lock is now only held across
    # in-memory work, never across a slow socket write.
    opened, fused = lock(root.deletion_lock) do
        # open the connection for e.g. subconnection, which just have an open flag
        open!(session.connection)
        if !isopen(session)
            # No live connection. If the session is actually CLOSED, bail with
            # nothing to do. Otherwise there's no socket (e.g. `NoConnection` /
            # offline export), but we still flip `connection_ready` so waiters
            # don't block — WITHOUT setting status=OPEN, writing a bundle, or
            # firing `on_open` (there is no frontend). `isready(session)` stays
            # false because the connection isn't open, so `_send` keeps queuing.
            if !isclosed(session) && !isready(session.connection_ready)
                put!(session.connection_ready, true)
            end
            @debug "Session $(session.id) has no open connection during init_session"
            return (false, nothing)
        end
        session.status = OPEN
        # Snapshot + drain the queued setup messages while holding the lock so
        # we don't race `get_messages!`'s `empty!`. `connection_ready` is still
        # un-signaled, so concurrent `_send`s queue behind us (they take the
        # same lock and, once we release it, see `isready == false` because
        # `connection_ready` hasn't been put! yet, so they queue rather than
        # overtake this bundle).
        if !isempty(session.message_queue) || !isempty(session.on_document_load)
            return (true, SerializedMessage(session, fused_messages!(session)))
        end
        return (true, nothing)
    end
    # Session got closed before we could open it: nothing to write, and in
    # particular don't fire the on_open notification below.
    opened || return
    # Blocking socket write OUTSIDE the lock, so a slow/backpressured client no
    # longer stalls every other lock taker (B36). We write the serialized
    # bundle DIRECTLY to the connection rather than via `_send`: `_send` would
    # see `isready == false` (connection_ready not yet signaled) and queue it.
    # If the direct write fails (disconnect mid-init), re-queue the bundle so a
    # later reconnect replays it.
    if fused !== nothing
        try
            write(session.connection, fused)
        catch e
            @debug "init_session bundle write failed; re-queueing for replay" exception = (e, catch_backtrace())
            lock(root.deletion_lock) do
                isclosed(session) || push!(session.message_queue, fused)
            end
        end
    end
    # Now signal ready and flush anything a concurrent `_send` queued while the
    # bundle was being written — those messages must go out AFTER the bundle,
    # which is exactly the order we get here. `connection_ready` is a one-shot
    # Channel{Bool}(1); a reconnect's second init_session would block on `put!`,
    # so guard with `isready`.
    lock(root.deletion_lock) do
        isclosed(session) && return
        if !isready(session.connection_ready)
            put!(session.connection_ready, true)
        end
        if !isempty(session.message_queue) || !isempty(session.on_document_load)
            send(session, fused_messages!(session))
        end
    end
    # Notify (re)connection listeners outside the lock: handlers may serialize
    # and send (e.g. WGLMakie re-synchronizing scene state on reconnect), which
    # takes the deletion_lock themselves. Fired after connection_ready is
    # signaled so those sends reach the wire directly instead of queueing.
    session.on_open[] = true
    return
end

session(session::Session) = session
# `Base.parent`, `isroot`, `root_session`, `root_data` are defined in types.jl
# (they need to be visible alongside the Session struct).

"""
    get_metadata(session, key::Symbol)
    get_metadata(session, key::Symbol, default)

Get metadata from the root session. Returns `nothing` or the provided `default` if key doesn't exist.
Metadata is stored on the root session and shared across all child sessions.
"""
function get_metadata(session::Session, key::Symbol, default=nothing)
    root = root_session(session)
    return lock(root.deletion_lock) do
        get(root.metadata, key, default)
    end
end

"""
    set_metadata!(session, key::Symbol, value)

Set metadata on the root session. Returns the value.
Metadata is stored on the root session and shared across all child sessions.
"""
function set_metadata!(session::Session, key::Symbol, value)
    root = root_session(session)
    lock(root.deletion_lock) do
        root.metadata[key] = value
    end
    return value
end

function get_session(session::Session, id::String)
    session.id == id && return session
    if haskey(session.children, id)
        return session.children[id]
    end
    # recurse
    for (key, sub) in session.children
        s = get_session(sub, id)
        isnothing(s) || return s
    end
    # Nothing found...
    return nothing
end

function free(session::Session)
    # `free` MUST take the root's deletion_lock itself — relying on callers
    # was racy: `process_message`'s `GetSessionDOM` branch (and any future
    # @async caller) can otherwise interleave with `close()` (which holds
    # the lock), corrupting `session_objects` mid-iteration. The lock is
    # reentrant, so callers that already hold it pay nothing extra.
    # See test/race_conditions_audit.jl F1.
    root = root_session(session)
    lock(root.deletion_lock) do
        # don't double free!
        session.status === CLOSED && return
        # unregister all cached objects from root session
        # If we're a child session, we need to remove all objects trackt in our root session:
        if session !== root
            # We need to remove our session from the parent first, otherwise `delete_cached!`
            # will think our session still holds the value, which would prevent it from deleting
            delete!(parent(session).children, session.id)
            # Snapshot the keys before iterating so concurrent renderers
            # adding to session_objects (under the same lock — they wait
            # until we exit) don't trip iteration.
            for key in collect(keys(session.session_objects))
                if haskey(root.session_objects, key)
                    delete_cached!(root, session, key)
                end
            end
        else
            # If this is a root session, we don't do any refcounting anymore
            # Since if root is over, everything is over.
            # and just delete everything!
            for key in collect(keys(session.session_objects))
                force_delete!(session, key)
            end
        end

        # delete_cached! only deletes in the root session so we need to still empty the session_objects:
        empty!(session.session_objects)
        empty!(session.on_document_load)
        empty!(session.message_queue)
        # remove all listeners that where created for this session
        foreach(off, session.deregister_callbacks)
        empty!(session.deregister_callbacks)
        # Asset/CSS bookkeeping that accumulated across this session's lifetime.
        # The WGLMakie memory-leak test asserts these are empty after close;
        # historically they leaked because nothing emptied them on the close path.
        empty!(session.imports)
        empty!(session.global_stylesheets)
        empty!(session.stylesheets)
        session.status = CLOSED
    end
    return
end

# B29: empty a *root* session for reuse — free its cached objects and queued
# state but keep the connection and status alive (unlike `free`, which sets
# CLOSED). Mirrors the root branch of `free` minus the status transition.
function Base.empty!(session::Session)
    root = root_session(session)
    root === session || error("empty!(::Session) is only valid for root sessions")
    lock(deletion_lock(root)) do
        session.status === CLOSED && return
        for key in collect(keys(session.session_objects))
            force_delete!(session, key)
        end
        empty!(session.session_objects)
        empty!(session.on_document_load)
        empty!(session.message_queue)
        foreach(off, session.deregister_callbacks)
        empty!(session.deregister_callbacks)
        empty!(session.imports)
        empty!(session.global_stylesheets)
        empty!(session.stylesheets)
    end
    return session
end

function soft_close(session::Session)
    # Guard against resurrecting a session that was explicitly CLOSED by user
    # code (B6). The WS handler's `finally` calls `soft_close` unconditionally;
    # without this guard a CLOSED session would flip to SOFT_CLOSED, `isclosed`
    # would report false again, and late `_send`s would queue into a
    # never-drained queue. Take the lock so the CLOSED-check and the status
    # write are atomic w.r.t. a concurrent `close()`.
    lock(deletion_lock(root_session(session))) do
        session.status === CLOSED && return
        session.status = SOFT_CLOSED
        session.closing_time = time()
    end
    return
end

function Base.close(session::Session)
    if isroot(session)
        close_root_session(session)
    else
        close_subsession(session)
    end
    return
end

# Upper bound on how long close waits for in-flight UpdateObservable listeners
# to drain. The real case drains in microseconds; the bound only guards against
# a listener that never returns (e.g. a blocked `evaljs_value`) wedging close.
const DISPATCH_DRAIN_TIMEOUT = 5.0

# Quiesce UpdateObservable dispatch before tearing the root down. Sets `closing`
# (under deletion_lock) so `process_message` admits no new dispatches, then waits
# for in-flight listeners to finish WITHOUT holding the lock — they run outside it
# and may call `evaljs_value`, which needs the lock (B1). After this returns no
# user listener is running, so the subsequent locked teardown flips CLOSED with
# nothing in flight (test/key_not_found_race.jl).
function drain_dispatch!(root::Session)
    already = lock(deletion_lock(root)) do
        root.status === CLOSED && return true
        root.closing = true
        return false
    end
    already && return
    deadline = time() + DISPATCH_DRAIN_TIMEOUT
    while root.dispatch_count[] > 0 && time() < deadline
        sleep(0.0005)
    end
    return
end

# Close path for the ROOT of a session tree. Tears down OS-level resources
# (the WS connection, the inbox channel) in addition to the per-session state
# that `close_subsession` handles.
function close_root_session(session::Session)
    # Stop admitting UpdateObservable dispatches and let in-flight listeners
    # drain BEFORE we take the lock, so none fires once teardown sets CLOSED.
    drain_dispatch!(session)
    # Capture the listeners we'll fire AFTER releasing the lock. `nothing`
    # signals "already closed, fire nothing" so a re-entrant close is a no-op.
    on_close_listeners = lock(deletion_lock(session)) do
        session.status === CLOSED && return nothing
        # Capture + clear listeners under the lock, then fire them OUTSIDE
        # the lock so user `on(session.on_close)` handlers can do anything
        # they like (including `evaljs_value` which spawns its own task to
        # acquire deletion_lock) without deadlock or recursion (B5). We also
        # mark the session CLOSED before firing so a listener that re-enters
        # `close()` short-circuits immediately on the guard above instead of
        # recursing forever (test/race_conditions_audit.jl F12).
        listeners = copy(session.on_close.listeners)
        Observables.clear(session.on_close)

        while !isempty(session.children)
            close(last(first(session.children))) # child removes itself from parent!
        end
        free(session)   # sets session.status = CLOSED
        close(session.asset_server)
        session.current_app[] = nothing
        session.io_context[] = nothing
        close(inbox(session))
        session.status = CLOSED
        close(connection(session))
        return listeners
    end
    # OUTSIDE the lock: status is already CLOSED, so a listener calling
    # `evaljs_value` (which spawns a task taking deletion_lock) can proceed.
    on_close_listeners === nothing && return
    for (_prio, f) in on_close_listeners
        try
            Base.invokelatest(f, true)
        catch e
            @warn "on_close listener threw" exception=(e, catch_backtrace())
        end
    end
    return
end

# Reactive teardown for a sub whose DOM has been swapped out but whose
# `ChildAssetServer` should stay alive for one more render so in-flight
# bundle fetches resolve. `free()` sets status=CLOSED, which makes
# `JSUpdateObservable` and `init_session` bail — that's what closes the
# race where a late JSDoneLoading round-trip would flush queued
# UpdateObservables at DOM nodes JS already removed. The caller's
# eventual `close(session)` (one render later via double-buffer) finishes
# the job; everything below is idempotent over this detach.
function detach_subsession!(session::Session)
    root = root_session(session)
    lock(deletion_lock(root)) do
        session.status === CLOSED && return
        for child in values(session.children)
            detach_subsession!(child)
        end
        free(session)
        # on_close fires in close_subsession; asset_server stays open
        # until then so in-flight fetches resolve.
    end
    return
end

# Subsession close. Idempotent over `detach_subsession!`: if detach
# already ran, this picks up the asset_server, JS notify, and on_close
# listeners. Does NOT touch the root's inbox or WS connection — those
# belong to the root and outlive any one sub.
function close_subsession(session::Session)
    root = root_session(session)
    on_close_listeners = lock(deletion_lock(root)) do
        # NOTE: we must NOT bail on `status === CLOSED` here — `detach_subsession!`
        # deliberately sets CLOSED (via `free`) while leaving the asset_server
        # open and on_close UNFIRED, expecting this function to finish the job
        # one render later. Re-entrancy is instead bounded by clearing
        # `on_close.listeners`: a second `close_subsession` captures an empty
        # listener set and fires nothing (the rest of the body is idempotent —
        # `free`, `close(asset_server)`, the JS free_session send).
        # Capture + clear listeners before any work so a re-entrant close
        # bails on the cleared set instead of looping.
        listeners = copy(session.on_close.listeners)
        Observables.clear(session.on_close)
        while !isempty(session.children)
            close(last(first(session.children)))
        end
        free(session)   # no-op if detach already CLOSED us
        # JS-side free; skip if the connection isn't ready (still
        # initializing or already torn down).
        isready(root; throw=false) && evaljs(root, js"""Bonito.free_session($(session.id))""")
        # ChildAssetServer.close is idempotent.
        close(session.asset_server)
        session.current_app[] = nothing
        session.io_context[] = nothing
        session.status = CLOSED
        return listeners
    end
    # Fire on_close OUTSIDE the lock (B5): a listener may call `evaljs_value`,
    # which spawns a task that takes deletion_lock — firing under the lock
    # would deadlock.
    on_close_listeners === nothing && return
    for (_prio, f) in on_close_listeners
        try
            Base.invokelatest(f, true)
        catch e
            @warn "on_close listener threw" exception=(e, catch_backtrace())
        end
    end
    return
end

"""
    send(session::Session; attributes...)

Send values to the frontend via MsgPack for now
"""
Sockets.send(session::Session; kw...) = send(session, Dict{Symbol, Any}(kw))

const COLLECT_MESSAGES = Threads.Atomic{Bool}(false)
const COLLECTED_MESSAGES = Dict{Symbol, Any}[]
const COLLECT_LOCK = Base.ReentrantLock()

function collect_message!(message)
    COLLECT_MESSAGES[] || return
    lock(COLLECT_LOCK) do
        if message isa SerializedMessage
            msg = decode_extension_and_addbits(deserialize(message))
        else
            msg = message
        end
        push!(COLLECTED_MESSAGES, (msg))
    end
end

function collect_messages(f)
    empty!(COLLECTED_MESSAGES)
    COLLECT_MESSAGES[] = true
    # MUST reset the flag in a `finally` (B16): otherwise a throw in `f()` (or
    # even a normal return before this was guarded) left `COLLECT_MESSAGES[]`
    # true process-wide, so EVERY subsequent outbound message got deep-decoded
    # and retained forever in `COLLECTED_MESSAGES` (unbounded memory growth).
    try
        f()
    finally
        COLLECT_MESSAGES[] = false
    end
    msgs = copy(COLLECTED_MESSAGES)
    len = length(msgs)
    s = Session(NoConnection(); asset_server=NoServer())
    total = mapreduce(+, msgs) do msg
        bytes = serialize_binary(s, msg)
        return sizeof(bytes)
    end
    msg = "Send $(len) messages with a total size of $(Base.format_bytes(total))"
    return msgs, msg
end

function Sockets.send(session::Session, message::SerializedMessage; large=false)
    collect_message!(message)
    _send(session, message, large)
end

function Sockets.send(session::Session, message::Dict{Symbol}; large=false)
    session.ignore_message[](message)::Bool && return
    collect_message!(message)
    _send(session, SerializedMessage(session, message), large)
end

# JSUpdateObservable now builds messages with String keys (avoids `string(k)`
# in serialize_cached). Mirror the Symbol-key dispatch so the same code path
# is taken.
function Sockets.send(session::Session, message::Dict{String}; large=false)
    session.ignore_message[](message)::Bool && return
    collect_message!(message)
    _send(session, SerializedMessage(session, message), large)
end

# Backwards compatibility for connections that dont expect a SerializedMessage but Vector{UInt8}
Base.write(connection::FrontendConnection, sm::SerializedMessage) = write(connection, serialize_binary(sm))

function _send(session::Session, sm::SerializedMessage, large::Bool)
    # The ready-check and the write/queue decision MUST be atomic w.r.t. the
    # UNINITIALIZED→OPEN transition (B4). `init_session` flushes the queue and
    # flips the session OPEN while holding `deletion_lock`; without the lock
    # here, three interleavings lose or reorder messages:
    #   (a) we see not-ready, init flushes + goes OPEN, then we push → the
    #       message strands in the queue until a reconnect that may not come;
    #   (b) we see ready in the gap between `put!(connection_ready)` and the
    #       flush → our direct write overtakes the queued registration
    #       messages (the F10 reordering the lock was meant to prevent);
    #   (c) `push!` races `get_messages!`'s `empty!` (called unlocked from
    #       `update_session_dom!`) → the message is erased unsent.
    # Holding `deletion_lock` across the decision + the write/push serializes
    # all of these against init_session, free, and get_messages!. The write is
    # non-blocking for the WS handler (it only buffers/sends one frame); the
    # blocking init-bundle write lives in init_session (B36), not here.
    #
    # `throw=false`: queueing-vs-writing is a connection-state question; if a
    # render error has been recorded we still want this message to land in the
    # queue (where the page wrap's init bundle picks it up) rather than crash
    # the surrounding render. External waiters surface the error themselves.
    lock(deletion_lock(root_session(session))) do
        if isready(session; throw=false)
            try
                if large
                    write_large(session.connection, sm)
                else
                    write(session.connection, sm)
                end
                return
            catch e
                # A write failure (disconnect mid-write) must fall back to the
                # queue for replay, not propagate out and lose the message
                # (B2/F11). `Base.write(::WebSocketHandler)` now rethrows on a
                # failed send so this catch actually fires.
                @debug "_send write failed; falling back to message_queue for replay" exception = (e, catch_backtrace())
                # fall through to push!
            end
        end
        push!(session.message_queue, sm)
    end
    return
end



function _send(session::Session, message::Dict, large::Bool)
    sm = SerializedMessage(session, message)
    _send(session, sm, large)
end

function HTTP.WebSockets.isclosed(session::Session)
    return session.status === CLOSED
end

function Base.isopen(session::Session)
    # A session is "open" iff it hasn't been individually closed AND the
    # root's transport is still alive. The status check handles the
    # subsession-closed-but-root-still-alive case (we no longer wrap subs
    # in their own SubConnection with a per-sub `isopen` flag).
    session.status === CLOSED && return false
    return isopen(connection(session))
end

"""
    isready(session::Session; throw::Bool=true) -> Bool

`true` once the frontend has connected (`connection_ready` flipped) and the
underlying connection is still open. `false` once the session has closed.

If `session.init_error[]` is set (frontend init failed, or `rendered_dom`
recorded a render-time error), the default behavior is to consume + throw
that exception so the caller surfaces the real cause instead of seeing a
silent closed session. Pass `throw=false` to opt out — used by sites that
only care about the connection state (logging via `show_session`, the
heartbeat ping, `_send`'s queue-or-write decision, `close`'s own evaljs
guard, etc.). Opting out is explicit: any caller asking "is this session
ready for usage" without that annotation cannot accidentally ignore a
recorded failure.
"""
function Base.isready(session::Session; throw::Bool=true)
    # `throw=true` (default) surfaces a recorded init/render error first, then
    # falls through to the connection check. The throw is consume-on-read so
    # the same exception doesn't fire on every poll. We don't close the session
    # — runtime errors leave the WS alive on purpose, so the
    # `JSUpdateObservable` carrying `indicator.error[] = err` reaches the
    # browser and any further runtime traffic (evaljs_value, observable
    # updates, …) keeps flowing. Callers decide whether the session is
    # unrecoverable and call `close(session)` explicitly if so.
    #
    # `throw=false` answers "is the WS ready right now?" only — used by
    # `_send`'s queue-or-write decision, the heartbeat, `show_session`, etc.
    # Those callers want the live connection state regardless of any
    # recorded failure, so they don't get blocked sending updates (notably
    # the indicator-error update itself) when init_error is set.
    if throw && !isnothing(session.init_error[])
        err = session.init_error[]
        session.init_error[] = nothing
        Base.throw(err)
    end
    isclosed(session) && return false
    return isready(session.connection_ready) && isopen(session)
end

"""
    onjs(session::Session, obs::Observable, func::JSCode)

Register a javascript function with `session`, that get's called when `obs` gets a new value.
If the observable gets updated from the JS side, the calling of `func` will be triggered
entirely in javascript, without any communication with the Julia `session`.
"""
function onjs(session::Session, obs::Observable, func::JSCode)
    send(
        session;
        msg_type=OnjsCallback,
        obs=obs,
        # return is needed to since on the JS side this will be wrapped in a function
        payload=JSCode([JSString("return "), func], func.file)
    )
end

function onjs(has_session, obs::Observable, func::JSCode)
    onjs(session(has_session), obs, func)
end

"""
    onload(session::Session, node::Node, func::JSCode)

calls javascript `func` with node, once node has been displayed.
"""
function onload(session::Session, node::Node, func::JSCode)
    wrapped_func = js"($(func))($(node));"
    # preserver fun.file
    on_document_load(session, JSCode(wrapped_func.source, func.file))
end

"""
    on_document_load(session::Session, js::JSCode)

executes javascript after document is loaded
"""
function on_document_load(session::Session, js::JSCode)
    push!(session.on_document_load, js)
end

"""
    linkjs(session::Session, a::Observable, b::Observable)

for an open session, link a and b on the javascript side. This will also
Link the observables in Julia, but only as long as the session is active.
"""
function linkjs(session::Session, a::Observable, b::Observable)
    # register the callback with the JS session
    onjs(session, a, js"""(v) => {$(b).notify(v)}""")
end

function linkjs(has_session, a::Observable, b::Observable)
    linkjs(session(has_session), a, b)
end

"""
    evaljs(session::Session, jss::JSCode)

Evaluate a javascript script in `session`.
"""
function evaljs(session::Session, jss::JSCode)
    # TODO, should we error for the user, if they call evaljs on a closed session?
    send(session; msg_type=EvalJavascript, payload=jss)
end

function evaljs(has_session, jss::JSCode)
    evaljs(session(has_session), jss)
end

"""
    evaljs_value(session::Session, js::JSCode)

Evals `js` code and returns the jsonified value.
Blocks until value is returned. May block indefinitely, when called with a session
that doesn't have a connection to the browser.
"""
function evaljs_value(session::Session, js; error_on_closed=true, timeout=10.0)
    root = root_session(session)
    if !isready(root)
        if error_on_closed
            error("Session is not open and would result in this function to indefinitely block.
            It may unblock, if the browser is still connecting and opening the session later on. If this is expected,
            you may try setting `error_on_closed=false`")
        end
        return nothing
    end
    # For each request we need a new observable to have this thread safe
    # And multiple request not waiting on the same observable
    comm = Observable{Any}(nothing)

    js_with_result = js"""{
        const comm = $(comm);
        try{
            const maybe_promise = $(js);
            // support returning a promise:
            Promise.resolve(maybe_promise).then(result=> {
                comm.notify({result});
            })
        }catch(e){
            comm.notify({error: e.toString()});
        } finally {
            // manually delete!
            Bonito.lock_loading(() => {
                // we need to free the object, since it exists outside of the session lifetime
                // and we don't want to keep it around forever
                Bonito.Sessions.force_free_object(comm.id);
            });
        }
    }
    """

    evaljs(session, js_with_result)
    # TODO, have an on error callback, that triggers when evaljs goes wrong
    # (e.g. because of syntax error that isn't caught by the above try catch!)
    # TODO do this with channels, but we still dont have a way to timeout for wait(channel)... so...
    result = fetch(Threads.@spawn wait_for(timeout=timeout) do
        lock(root.deletion_lock) do
            Bonito.isclosed(session) && return :closed
            return !isnothing(comm[])
        end
    end)
    value = comm[]
    # Manually free observable, since it exists outside session lifetimes.
    # `register_observable!` attaches a JSUpdateObservable listener keyed by the
    # observable's cache key, so we must strip it explicitly here — the
    # session's own `free()` won't, since this comm lives outside the session
    # lifetime. See test/race_conditions_audit.jl F5.
    # Registration is keyed by `cache_key(session, comm)`, NOT `comm.id` — on a
    # ProxyConnection session those differ (the key is `prefix/comm.id`).
    # Deleting by `comm.id` left a leaked CachedEntry per call on proxied
    # sessions (B27). Use the same key the registration used. `remove_js_updates!`
    # also matches by key (the JSUpdateObservable's `.id` is the cache key).
    key = cache_key(session, comm)
    lock(root.deletion_lock) do
        remove_js_updates!(key, comm)
        delete!(session.session_objects, key)
        delete!(root.session_objects, key)
    end
    Observables.clear(comm) # cleanup
    result == :closed && return
    if isnothing(value)
        error("Timed out")
    end
    if haskey(value, "error")
        error(value["error"])
    else
        return value["result"]
    end
end

function evaljs_value(with_session, js; error_on_closed=true, timeout=100.0)
    evaljs_value(session(with_session), js; error_on_closed=error_on_closed, timeout=timeout)
end

function session_dom(session::Session, app::App; init=true, html_document=false)
    dom = rendered_dom(session, app)
    # Ensure we have a valid DOM node (handles App(nothing; indicator=nothing))
    if isnothing(dom)
        dom = DOM.div()
    end
    try
        return session_dom(session, dom; init=init, html_document=html_document)
    catch err
        # Page-wrap failure (msgpack pack error on the init bundle, broken
        # asset, etc). The user handler already returned cleanly so it isn't
        # *its* error, but we still need to surface the cause: stamp it on
        # `session.init_error[]` so any caller waiting on `isready(session)`
        # (wait_for_ready, bench, tests) sees it instead of timing out on a
        # session stuck at UNINITIALIZED. Then ship a minimal error page
        # without re-attempting the broken init bundle (`init=false`).
        bt = Base.catch_backtrace()
        @error "Error wrapping page" exception=(err, bt)
        record_session_error!(session, err)
        return session_dom(session, HTTPServer.err_to_html(err, bt);
                           init=false, html_document=html_document)
    end
end

function push_dependencies!(childs, session::Session)
    require_off = DOM.script("""
        window.__define = window.define;
        window.__require = window.require;
        window.define = undefined;
        window.require = undefined;
    """)
    require_on = DOM.script("""
        window.define = window.__define;
        window.require = window.__require;
        window.__define = undefined;
        window.__require = undefined;
    """)
    # Dedupe asset emission at the page (root) level for the page's lifetime.
    # Once a `<script type=module>` / `<link>` for an asset lands in the
    # document, the browser keeps the module loaded for as long as the page
    # is alive — even after the sub-session that emitted it closes (the tag
    # is in the page's head, not in the sub's swappable DOM, and module
    # registry entries are per-page). So we propagate every sub's `imports`
    # into `root.imports` here and never decrement on sub-close (mirror in
    # `free()` deliberately omitted). `root.imports` is cleared along with
    # the rest of root state when the root session itself closes. Bounded
    # by the application's distinct asset surface, not by user input.
    # test/basics.jl "dependency second include" locks this in.
    if isroot(session)
        assets = session.imports
    else
        root = root_session(session)
        assets = lock(root.deletion_lock) do
            new = setdiff(session.imports, root.imports)
            union!(root.imports, new)
            return new
        end
    end

    assets_rendered = render_asset.(Ref(session), Ref(session.asset_server), assets)
    if any(x-> mediatype(x) == :js && !x.es6module, assets)
        # if a js non es6module is included, we may need to hack require... because JS! :(
        push!(childs, require_off)
        push!(childs, assets_rendered...)
        push!(childs, require_on)
    else
        push!(childs, assets_rendered...)
    end
end

function mark_displayed!(session::Session)
    # Don't overwrite a CLOSED session with DISPLAYED (B6) — `isclosed` would
    # flip back to false on a freed session. Atomic with a concurrent close.
    lock(deletion_lock(root_session(session))) do
        session.status === CLOSED && return
        session.status = DISPLAYED
        session.closing_time = time()
    end
    return
end



function get_messages!(session::Session, messages=[])
    append!(messages, session.message_queue)
    for js in session.on_document_load
        onload = Dict(:msg_type=>EvalJavascript, :payload=>js)
        push!(messages, SerializedMessage(session, onload))
    end
    empty!(session.on_document_load)
    empty!(session.message_queue)
    return messages
end

fused_messages!(session::Session) = Dict(:msg_type=>FusedMessage, :payload=>get_messages!(session))

function collect_session_objects!(session::Session, objects=Vector{Any}[])
    ob = []
    for msg in session.message_queue
        for (k, v) in msg.cache.objects
            push!(ob, [k, v])
        end
        empty!(msg.cache.objects)
    end
    typ = root_session(session) === session ? "root" : "sub"
    push!(objects, [session.id, ob, typ])
    for (k, child) in session.children
        collect_session_objects!(child, objects)
    end
    return objects
end


function session_dom(session::Session, dom::Node; init=true, html_document=false, dom_id=isroot(session) ? "root" : "subsession-application-dom")
    lock(root_session(session).deletion_lock) do
        # the dom we can render may be anything between a
        # dom fragment or a full page with head & body etc.
        # If we have a head & body, we want to append our initialization
        # code and dom nodes to the right places, so we need to extract those
        head, body, dom = find_head_body(dom)
        session_style = render_stylesheets!(root_session(session), session, session.stylesheets)
        # Root sessions ship the built-in widget theme (light + prefers-dark CSS
        # variables) so standalone apps follow the OS color scheme. OrderedSet
        # dedups, so adding the same const repeatedly is a no-op.
        isroot(session) && push!(session.global_stylesheets, BONITO_WIDGET_THEME)
        global_styles = map(collect(session.global_stylesheets)) do styles
            DOM.style(to_string(session, styles))
        end
        issubsession = !isroot(session)

        # should never request full html_doc for subsession
        issubsession && @assert !html_document
        if issubsession && !isnothing(head) && !isnothing(body)
            @warn "Apps with head/body elements are not supported in subsessions, wrapping in a fragment"
            dom = page_to_fragment(head, body, dom)
            head = body = nothing
        end

        # if nothing is found, we just use one div and append to that
        if isnothing(head) && isnothing(body)
            if html_document
                # emit a whole html document
                body_dom = DOM.div(dom, id=session.id, dataJscallId=dom_id)
                head = Hyperscript.m("head",
                    Hyperscript.m(
                        "meta";
                        name="viewport", content="width=device-width, initial-scale=1.0"
                    ),
                    Hyperscript.m("meta"; charset="UTF-8"),
                    Hyperscript.m("title", session.title),
                    session_style, global_styles...
                )
                body = Hyperscript.m("body", body_dom)
                dom = Hyperscript.m("html", head, body; class="bonito-fragment")
            else
                # Emit a "fragment". The wrapper divs are purely structural —
                # they exist as DOM anchors for Bonito's reactive swap logic
                # and the per-session stylesheet. style="display:contents"
                # makes them transparent to the surrounding flex/grid layout
                # so an Observable rendered into a flex container behaves the
                # same as if the content were a direct child.
                head = DOM.div(session_style, global_styles...; style="display:contents")
                body = DOM.div(dom; style="display:contents")
                dom = DOM.div(
                    head, body;
                    id=session.id, class="bonito-fragment", dataJscallId=dom_id,
                    style="display:contents",
                )
            end
        else
            push!(children(head), session_style)
            append!(children(head), global_styles)
        end
        # first render BonitoLib
        Bonito_import = DOM.script(src=url(session, BonitoLib), type="module")
        init_server = setup_asset_server(session.asset_server)
        if !isnothing(init_server)
            pushfirst!(children(body), jsrender(session, init_server))
        end
        # Only roots get connection-init JS injected. Subsessions share
        # the root's transport — running setup_connection for them would
        # re-register the WS route under the sub's id, overwriting the
        # WebSocketConnection.session field with the sub. The old design
        # encoded this as `Session{SubConnection}` dispatching to a no-op;
        # we now branch explicitly on isroot.
        init_connection = isroot(session) ? setup_connection(session) : nothing
        if !isnothing(init_connection)
            pushfirst!(children(body), jsrender(session, init_connection))
        end

        if init
            msgs = get_messages!(session)
            type = issubsession ? "sub" : "root"
            binary = isempty(msgs) ? "null" : "Bonito.fetch_binary('$(url(session, BinaryAsset(session, msgs)))')"
            init_session = """
            Bonito.init_session($(repr(session.id)), $(binary), $(repr(type)), $(session.compression_enabled));
            """
            pushfirst!(children(body), inline_code(session, session.asset_server, init_session))
        end

        # `push_dependencies!` MUST come after `get_messages!` — message
        # serialization is what triggers `print_js_code` for any
        # `$(es6module)` interpolations inside `js"..."` blocks, and that
        # is what registers the asset into `session.imports`. If we ran
        # `push_dependencies!` first, those modules would be missing from
        # the head and the browser couldn't start parsing them in
        # parallel with the bootstrap bin — every `$(es6module).then`
        # would pay the full dynamic-import-after-bin-runs latency.
        push_dependencies!(children(head), session)

        if !issubsession
            pushfirst!(children(head), Bonito_import)
        end
        session.status = RENDERED
        return dom
    end
end

function page_to_fragment(head, body, dom)
    _head = Hyperscript.Node(
        Hyperscript.context(head),
        "div",
        Hyperscript.children(head),
        Hyperscript.attrs(head)
    )
    _body = Hyperscript.Node(
        Hyperscript.context(body),
        "div",
        Hyperscript.children(body),
        Hyperscript.attrs(body)
    )
    return Hyperscript.Node(
        Hyperscript.context(dom),
        "div",
        [_head, _body],
        Hyperscript.attrs(dom)
    )
end

function render_subsession(p::Session, data; init=false)
    return render_subsession(p, App(DOM.span(data); loading_page=nothing); init=init)
end

function render_subsession(parent::Session, app::App; init=false)
    sub = Session(parent)
    return sub, session_dom(sub, app; init=init)
end

function render_subsession(parent::Session, dom::Node; init=false)
    sub = Session(parent)
    dom_rendered = jsrender(sub, dom)
    return sub, session_dom(sub, dom_rendered; init=init)
end

function update_session_dom!(parent::Session, node_uuid::String, app_or_dom; replace=true)
    if isclosed(parent)
        error("Updating the session dom for a closed session")
    end
    sub, html = render_subsession(parent, app_or_dom; init=false)
    # We need to manually do the serialization,
    # Since we send it via the parent, but serialization needs to happen
    # for `sub`.
    # sub is not open yet, and only opens if we send the below message for initialization
    # which is why we need to send it via the parent session
    UpdateSession = "12" # msg type
    session_update = Dict(
        "msg_type" => UpdateSession,
        "session_id" => sub.id,
        "session_status" => "sub",
        "messages" => get_messages!(sub),
        "html" => html,
        "replace" => replace,
        "dom_node_selector" => node_uuid
    )
    message = SerializedMessage(sub, session_update)
    send(root_session(parent), message)
    mark_displayed!(parent)
    mark_displayed!(sub)
    return sub
end

function dom_in_js(parent::Session,  new_html, js_func)
    if isclosed(parent)
        error("Updating the session dom for a closed session")
    end
    sub, html = render_subsession(parent, new_html; init=true)
    html_obs = Observable(html)
    update_dom = js"""($(js_func))($(html_obs).value)"""
    message = Bonito.SerializedMessage(
        sub, Dict(:msg_type => Bonito.EvalJavascript, :payload => update_dom)
    )
    Bonito.send(parent, message)
    mark_displayed!(parent)
    mark_displayed!(sub)
    return sub
end


function append_child(parent::Session, parent_node::HTMLElement, new_html)
    return dom_in_js(parent, new_html, js"""(elem) => {
        $(parent_node).appendChild(elem);
    }""")
end

function update_subsession_dom!(sub::Session, selector, app::App)
    html = session_dom(sub, app; init=false)
    # We need to manually do the serialization,
    # Since we send it via the parent, but serialization needs to happen
    # for `sub`.
    # sub is not open yet, and only opens if we send the below message for initialization
    # which is why we need to send it via the parent session
    UpdateSession = "12" # msg type
    session_update = Dict(
        "msg_type" => UpdateSession,
        "session_id" => sub.id,
        "messages" => get_messages!(sub),
        "html" => html,
        "replace" => true,
        "dom_node_selector" => selector
    )
    message = SerializedMessage(sub, session_update)
    send(root_session(sub), message)
    mark_displayed!(sub)
    return sub
end
