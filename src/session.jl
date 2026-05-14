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
    # Hold deletion_lock across the open-and-flush so a concurrent send
    # can't interleave between `isready` flipping true and the queue drain.
    # Without the lock, the concurrent send sees `isready==true`, takes the
    # direct-write branch in `_send`, and its message can land on the wire
    # BEFORE the queued setup messages — JS sees an UpdateObservable for a
    # key whose registration arrives later. See test/race_conditions_audit.jl F10.
    lock(root_session(session).deletion_lock) do
        # `connection_ready` is a one-shot Channel{Bool}(1). A second
        # init_session for the same session (websocket reconnect → fresh
        # JSDoneLoading) would block on `put!` here, and — now that this
        # block holds `deletion_lock` — deadlock every other lock-taker.
        # Guard with `isready` so reconnects are a no-op on the signal.
        if !isready(session.connection_ready)
            put!(session.connection_ready, true)
        end
        # open the connection for e.g. subconnection, which just have an open flag
        open!(session.connection)
        if !isopen(session)
            @debug "Session $(session.id) closed before init_session could run"
            return
        end
        # We send all queued up messages once the connection is open
        if !isempty(session.message_queue) || !isempty(session.on_document_load)
            send(session, fused_messages!(session))
        end
        session.status = OPEN
    end
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

function soft_close(session::Session)
    session.status = SOFT_CLOSED
    session.closing_time = time()
end

function Base.close(session::Session)
    if isroot(session)
        close_root_session(session)
    else
        close_subsession(session)
    end
    return
end

# Close path for the ROOT of a session tree. Tears down OS-level resources
# (the WS connection, the inbox channel) in addition to the per-session state
# that `close_subsession` handles.
function close_root_session(session::Session)
    lock(deletion_lock(session)) do
        session.status === CLOSED && return
        # Capture + clear listeners under the lock, then fire them OUTSIDE
        # the lock so user `on(session.on_close)` handlers can do anything
        # they like (including `evaljs_value` which spawns its own task to
        # acquire deletion_lock) without deadlock or recursion. We also
        # mark the session CLOSED before firing so a listener that re-enters
        # `close()` short-circuits immediately on the guard above instead of
        # recursing forever (test/race_conditions_audit.jl F12).
        on_close_listeners = copy(session.on_close.listeners)
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

        for (_prio, f) in on_close_listeners
            try
                Base.invokelatest(f, true)
            catch e
                @warn "on_close listener threw" exception=(e, catch_backtrace())
            end
        end
    end
    return
end

# Close path for a SUBSESSION. Releases this subsession's per-render state
# and its `asset_server` refcount contributions. Does NOT touch the root's
# inbox or WS connection — those belong to the root and outlive any one sub.
function close_subsession(session::Session)
    root = root_session(session)
    lock(deletion_lock(root)) do
        session.status === CLOSED && return
        on_close_listeners = copy(session.on_close.listeners)
        Observables.clear(session.on_close)

        while !isempty(session.children)
            close(last(first(session.children)))
        end
        free(session)   # sets session.status = CLOSED
        # Tell JS to drop its mirror of this sub-session.
        # If the connection isn't ready (still initializing or already torn down),
        # skip the message — there's nothing to tell.
        isready(root; throw=false) && evaljs(root, js"""Bonito.free_session($(session.id))""")
        close(session.asset_server)
        session.current_app[] = nothing
        session.io_context[] = nothing
        session.status = CLOSED

        for (_prio, f) in on_close_listeners
            try
                Base.invokelatest(f, true)
            catch e
                @warn "on_close listener threw" exception=(e, catch_backtrace())
            end
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
    f()
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
    # The check-then-act between `isready(session)` and `write(...)` is
    # racy: a disconnect in the gap (or any write failure) used to throw
    # out of `_send` AND lose the message — neither queued for replay nor
    # on the wire. Wrap the write so a failure falls back to the queue,
    # which `init_session` flushes on (re)connect. Test:
    # test/race_conditions_audit.jl F11.
    # `throw=false`: queueing-vs-writing is a connection-state question; if a
    # render error has been recorded we still want this message to land in the
    # queue (where the page wrap's init bundle picks it up) rather than crash
    # the surrounding render. External waiters surface the error themselves.
    if isready(session; throw=false)
        try
            if large
                write_large(session.connection, sm)
            else
                write(session.connection, sm)
            end
            return
        catch e
            @debug "_send write failed; falling back to message_queue for replay" exception = (e, catch_backtrace())
            # fall through to push!
        end
    end
    push!(session.message_queue, sm)
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
    # `register_observable!` attaches a JSUpdateObservable listener bound
    # to *the sub session*, so we have to call `remove_js_updates!(sub, comm)`
    # explicitly — `force_delete!(root, ...)` only matches root-bound
    # listeners and would leak a sub-bound one. See test/race_conditions_audit.jl F5.
    lock(root.deletion_lock) do
        remove_js_updates!(session, comm)
        delete!(session.session_objects, comm.id)
        delete!(root.session_objects, comm.id)
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
    session.status = DISPLAYED
    session.closing_time = time()
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
