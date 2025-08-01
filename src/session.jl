function show_session(io::IO, session::Session{T}) where T
    println(io, "Session{$T}:")
    println(io, "  id: $(session.id)")
    println(io, "  parent: $(typeof(session.parent))")
    println(io, "  status: $(session.status)")
    if !isempty(session.children)
        println(io, "children: $(length(session.children))")
    end
    println(io, "  connection: $(isopen(session.connection) ? "open" : "closed")")
    println(io, "  isready: $(isready(session))")
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

function get_messages!(session::Session, messages=[])
    root = root_session(session)
    if root !== session
        get_messages!(root, messages)
    end
    append!(messages, session.message_queue)
    for js in session.on_document_load
        onload = Dict(:msg_type=>EvalJavascript, :payload=>js)
        push!(messages, SerializedMessage(session, onload))
    end
    empty!(session.on_document_load)
    empty!(session.message_queue)
    return messages
end

function fused_messages!(session::Session)
    messages = get_messages!(session)
    return Dict(:msg_type=>FusedMessage, :payload=>messages)
end

function init_session(session::Session)
    put!(session.connection_ready, true)
    # open the connection for e.g. subconnection, which just have an open flag
    open!(session.connection)
    @assert isopen(session)
    # We send all queued up messages once the onnection is open
    if !isempty(session.message_queue) || !isempty(session.on_document_load)
        send(session, fused_messages!(session))
    end
    session.status = OPEN
    return
end

session(session::Session) = session
Base.parent(session::Session) = session.parent
root_session(session::Session) = isnothing(parent(session)) ? session : root_session(parent(session))

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
    # don't double free!
    session.status === CLOSED && return
    # unregister all cached objects from root session
    root = root_session(session)
    # If we're a child session, we need to remove all objects trackt in our root session:
    if session !== root
        # We need to remove our session from the parent first, otherwise `delete_cached!`
        # will think our session still holds the value, which would prevent it from deleting
        delete!(parent(session).children, session.id)
        for key in keys(session.session_objects)
            if haskey(root.session_objects, key)
                delete_cached!(root, session, key)
            end
        end
    else
        # If this is a root session, we don't do any refcounting anymore
        # Since if root is over, everything is over.
        # and just delete everything!
        for key in keys(session.session_objects)
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
    session.status = CLOSED
    return
end

function soft_close(session::Session)
    session.status = SOFT_CLOSED
    session.closing_time = time()
end

function Base.close(session::Session)
    lock(root_session(session).deletion_lock) do
        session.status === CLOSED && return
        session.on_close[] = true
        while !isempty(session.children)
            close(last(first(session.children))) # child removes itself from parent!
        end
        free(session)
        # unregister all cached objects from parent session
        root = root_session(session)
        # If we're a child session, we need to remove all objects tracked in our root session:
        if session !== root
            # Close child session on js side as well
            # If not ready, we already lost connection to JS frontend, so no need to close things on the JS side
            isready(root) && evaljs(root, js"""Bonito.free_session($(session.id))""")
        end
        close(session.asset_server)
        Observables.clear(session.on_close)
        session.current_app[] = nothing
        session.io_context[] = nothing
        close(session.inbox)
        session.status = CLOSED
        close(session.connection)
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

# Backwards compatibility for connections that dont expect a SerializedMessage but Vector{UInt8}
Base.write(connection::FrontendConnection, sm::SerializedMessage) = write(connection, serialize_binary(sm))

function _send(session::Session, sm::SerializedMessage, large::Bool)
    if isready(session)
        if large
            write_large(session.connection, sm)
        else
            write(session.connection, sm)
        end
    else
        push!(session.message_queue, sm)
    end
end



function _send(session::Session, message::Dict, large::Bool)
    sm = SerializedMessage(session, message)
    _send(session, sm, large)
end

function HTTP.WebSockets.isclosed(session::Session)
    return session.status === CLOSED
end

Base.isopen(session::Session) = isopen(session.connection)

function Base.isready(session::Session)
    isclosed(session) && return false
    if !isnothing(session.init_error[])
        err = session.init_error[]
        session.init_error[] = nothing
        close(session)
        throw(err)
    end
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
    # manually free observable, since it exists outside session lifetimes
    lock(root.deletion_lock) do
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
    return session_dom(session, dom; init=init, html_document=html_document)
end

isroot(session::Session) = session.parent === nothing

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
    if isroot(session)
        assets = session.imports
    else
        # only render the assets that aren't already in root session
        assets = setdiff(session.imports, root_session(session).imports)
        union!(root_session(session).imports, session.imports)
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

function session_dom(session::Session, dom::Node; init=true, html_document=false, dom_id=isroot(session) ? "root" : "subsession-application-dom")
    lock(root_session(session).deletion_lock) do
        # the dom we can render may be anything between a
        # dom fragment or a full page with head & body etc.
        # If we have a head & body, we want to append our initialization
        # code and dom nodes to the right places, so we need to extract those
        head, body, dom = find_head_body(dom)
        session_style = render_stylesheets!(root_session(session), session, session.stylesheets)
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
                    session_style
                )
                body = Hyperscript.m("body", body_dom)
                dom = Hyperscript.m("html", head, body; class="bonito-fragment")
            else
                # Emit a "fragment"
                head = DOM.div(session_style)
                body = DOM.div(dom)
                dom = DOM.div(
                    head, body; id=session.id, class="bonito-fragment", dataJscallId=dom_id
                )
            end
        else
            push!(children(head), session_style)
        end
        # first render BonitoLib
        Bonito_import = DOM.script(src=url(session, BonitoLib), type="module")
        init_server = setup_asset_server(session.asset_server)
        if !isnothing(init_server)
            pushfirst!(children(body), jsrender(session, init_server))
        end
        init_connection = setup_connection(session)
        if !isnothing(init_connection)
            pushfirst!(children(body), jsrender(session, init_connection))
        end

        push_dependencies!(children(head), session)

        if init
            msgs = fused_messages!(session)
            type = issubsession ? "sub" : "root"
            if isempty(msgs[:payload])
                init_session = js"""Bonito.lock_loading(() => Bonito.init_session($(session.id), null, $(type), $(session.compression_enabled)))"""
            else
                binary = BinaryAsset(session, msgs)
                init_session = js"""
                    Bonito.lock_loading(() => {
                        return $(binary).then(msgs=> Bonito.init_session($(session.id), msgs, $(type), $(session.compression_enabled)));
                    })
                """
            end
            pushfirst!(children(body), jsrender(session, init_session))
        end

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
    return render_subsession(p, App(DOM.span(data)); init=init)
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
        "messages" => fused_messages!(sub),
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
