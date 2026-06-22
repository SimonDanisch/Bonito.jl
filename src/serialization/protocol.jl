# Save some bytes by using ints for switch variable
const UpdateObservable = "0"
const OnjsCallback = "1"
const EvalJavascript = "2"
const JavascriptError = "3"
const JavascriptWarning = "4"
const RegisterObservable = "5"
const JSDoneLoading = "8"
const FusedMessage = "9"
const CloseSession = "10"
const PingPong = "11"
const UpdateSession = "12"
const GetSessionDOM = "13"

"""
    process_message(session::Session, bytes::AbstractVector{UInt8})

Handles the incoming websocket messages from the frontend.
Messages are expected to be gzip compressed and packed via MsgPack.
"""
function process_message(session::Session, bytes::AbstractVector{UInt8})
    if isempty(bytes)
        @warn "empty message received from frontend"
        return
    end
    data = deserialize_binary(bytes, session.compression_enabled)
    return process_message(session, data)
end

# Decoded-frame entry point. Split out from the bytes path so a proxied worker
# session can be handed an already-decoded frame (forwarded by the host's
# `route_to_remote`) without a re-encode/decode round trip.
function process_message(session::Session, data::AbstractDict)
    # A proxied worker session's frames — its observable updates (object id) and
    # session lifecycle (`JSDoneLoading`/`CloseSession`/`GetSessionDOM`, session
    # id) — carry ids namespaced to that worker. Forward the decoded frame and let
    # the worker handle it against its real session tree; the server keeps no
    # mirror of the worker's objects/sessions, it just relays by namespace. A
    # no-op (returns false) for the server's own frames, whose ids never match a
    # registered worker prefix.
    route_to_remote(session, data) && return
    typ = data["msg_type"]
    if typ == UpdateObservable
        # Look up + COPY the cached object reference under the root's
        # deletion_lock, then release the lock BEFORE invoking
        # `update_nocycle!`. The user listeners fired by `update_nocycle!`
        # are normal application code — they may call `evaljs_value`, which
        # spawns a task that itself takes `deletion_lock`. Holding the lock
        # across the user callback therefore deadlocks the whole session
        # tree (the message task blocks in `fetch` while holding the lock).
        # The lock only needs to guard the Dict access against a concurrent
        # `close(session)` tearing down `session_objects`; once we have the
        # object reference, we re-check `isclosed` and dispatch outside it.
        root = root_session(session)
        # Look up the object AND claim a dispatch slot under the lock, so the
        # decision to dispatch is atomic w.r.t. `close` (which sets `closing`
        # under the same lock and then drains `dispatch_count` before flipping
        # CLOSED). Once admitted, the listener runs OUTSIDE the lock (it may
        # call `evaljs_value`, which needs the lock — holding it across the
        # callback deadlocks). `close` waiting for `dispatch_count == 0`
        # without the lock is what guarantees no listener fires after CLOSED
        # while staying deadlock-free.
        obj = lock(root.deletion_lock) do
            (isclosed(session) || root.closing) && return nothing
            # Sub sessions only carry markers (`nothing`) — the actual
            # cached object lives on the root via CachedEntry. Try the
            # session first (covers root) then fall back to root.
            entry = get(session.session_objects, data["id"], nothing)
            if entry === nothing && session !== root
                entry = get(root.session_objects, data["id"], nothing)
            end
            entry === nothing && return nothing
            Threads.atomic_add!(root.dispatch_count, 1)
            return entry isa CachedEntry ? entry.object : entry
        end
        if obj === nothing
            # this is usually non fatal and may happen when old exported HTML gets reconnected
            @debug "Observable $(data["id"]) not found (or session closed/closing)"
        else
            try
                # `session` is the originating session: `update_nocycle!` skips
                # only that session's JS updater so the value doesn't echo back
                # to the browser that just sent it, while OTHER sessions sharing
                # the same observable still receive the update.
                Base.invokelatest(update_nocycle!, obj, data["payload"], session)
            finally
                Threads.atomic_sub!(root.dispatch_count, 1)
            end
        end
    elseif typ == JavascriptError
        show(stderr, JSException(session, data))
    elseif typ == JavascriptWarning
        @warn "Error in Javascript: $(data["message"])\n)"
    elseif typ == JSDoneLoading
        # Bail early if the receiving session is already torn down. The
        # message may have been dispatched from the inbox @async pool
        # *after* close() ran.
        if isclosed(session)
            @debug "JSDoneLoading on a closed session — ignoring"
        elseif data["exception"] != "nothing"
            exception = JSException(session, data)
            show(stderr, exception)
            # Route through the shared helper so the connection indicator's
            # error observable picks up the cause. The WS is already up
            # (we're processing a message it delivered), so the resulting
            # JSUpdateObservable actually reaches the browser.
            record_session_error!(session, exception)
        else
            # `get_session` recurses through `session.children`, which is
            # mutated under `deletion_lock` by close/free/Session(parent).
            # Iterating it unlocked races those mutations. Snapshot the
            # lookup under the lock; fire `on_connection_ready` outside it.
            root = root_session(session)
            sub = lock(root.deletion_lock) do
                get_session(session, data["session"])
            end
            if !isnothing(sub) && !isclosed(sub)
                # this may block the connection!
                @async try
                    isclosed(sub) && return
                    sub.on_connection_ready(sub)
                catch e
                    @warn "error while processing on_connection_ready" exception = (e, Base.catch_backtrace())
                end
            elseif isnothing(sub)
                # This can happen for IJulia output after kernel restart,
                # since the loaded html will try to init + connect back
                # TODO, there should be a better way to prevent them from reconnecting
                @debug("Sub session with id $(data["session"]) not found")
            else
                @debug "JSDoneLoading for closed sub $(data["session"]) — ignoring"
            end
        end
    elseif typ == CloseSession
        if isclosed(session)
            @debug "CloseSession on already-closed session — ignoring"
        else
            # Same unlocked-recursion race as JSDoneLoading: take the
            # lock for the `get_session` walk over `session.children`.
            root = root_session(session)
            sub = lock(root.deletion_lock) do
                get_session(session, data["session"])
            end
            if !isnothing(sub)
                if data["subsession"] != "root"
                    close(sub)
                elseif root_session(sub) === sub
                    # We only empty root sessions, since they will be reused.
                    empty!(sub)
                else
                    # `subsession` is client-controlled — a stale/malformed
                    # frame claiming "root" for a sub-session id must not crash
                    # the inbox task (the old `@assert` did). Log and ignore.
                    @warn "CloseSession claimed subsession==\"root\" for a non-root session — ignoring" id=data["session"]
                end
            else
                @debug("Close request not succesful, can't find sub session with id $(data["session"])")
            end
        end
    elseif typ == PingPong
        # Ping back that pong!!
        # Heartbeat — `throw=false`: a recorded init_error shouldn't crash the ping handler.
        isready(session; throw=false) && send(session, msg_type=PingPong)
    elseif typ == GetSessionDOM
        # Hold deletion_lock for the entire body — the original code
        # called `empty!(session.session_objects)` and mutated
        # `session.children` outside any lock, which races concurrent
        # `add_cached!` paths and silently wipes the root cache mid-flight.
        root = root_session(session)
        @async try
            lock(root.deletion_lock) do
                isclosed(session) && return
                sub = get_session(session, data["session"])
                if !isnothing(sub)
                    app = sub.current_app[]
                    if isnothing(app)
                        @warn "requesting dom for uninitialized app"
                    else
                        free(sub)
                        session.children[sub.id] = sub
                        # NOTE: the empty!(session.session_objects) that
                        # used to be here was indiscriminately wiping the
                        # *root* cache (the cache shared by all sub
                        # sessions on this connection). Removed; the
                        # individual sub's cache is already cleared by
                        # `free(sub)` above.
                        open!(sub.connection)
                        sub.status = OPEN
                        update_subsession_dom!(sub, data["replace"], app)
                    end
                else
                    @warn "cant update session is nothing"
                end
            end
        catch e
            @warn "error while processing update App message" exception = (e, Base.catch_backtrace())
        end
    else
        @error "Unrecognized message: $(typ) with type: $(typeof(typ))"
    end
end
