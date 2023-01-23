function show_session(io::IO, session::Session{T}) where T
    println(io, "Session{$T}:")
    println(io, "  id: $(session.id)")
    println(io, "  parent: $(typeof(session.parent[]))")
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

function wait_for_ready(session::Session; timeout=10)
    wait_for(()-> isready(session); timeout=timeout)
end

function get_messages!(session::Session, messages=[])
    append!(messages, session.message_queue)
    for js in session.on_document_load
        push!(messages, Dict(:msg_type=>EvalJavascript, :payload=>js))
    end
    empty!(session.on_document_load)
    empty!(session.message_queue)
    root = root_session(session)
    if root !== session
        get_messages!(root, messages)
    end
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
end

session(session::Session) = session

Base.parent(session::Session) = session.parent[]

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

function Base.empty!(session::Session)
    root = root_session(session)
    for key in keys(session.session_objects)
        delete_cached!(root, key)
    end
    # remove all listeners that where created for this session
    foreach(off, session.deregister_callbacks)
    empty!(session.deregister_callbacks)
end

function Base.close(session::Session)
    # unregister all cached objects from parent session
    root = root_session(session)
    # If we're a child session, we need to remove all objects trackt in our root session:
    if session !== root
        # We need to remove our session from the parent first, otherwise `delete_cached!`
        # will think our session still holds the value, which would prevent it from deleting
        delete!(parent(session).children, session.id)
        for key in keys(session.session_objects)
            delete_cached!(root, key)
        end
        evaljs(root, js"""
            JSServe.free_session($(session.id))
        """)
    end
    # delete_cached! only deletes in the root session so we need to still empty the session_objects:
    empty!(session.session_objects)

    close(session.connection)
    empty!(session.on_document_load)
    empty!(session.message_queue)
    empty!(session.session_objects)
    # remove all listeners that where created for this session
    foreach(off, session.deregister_callbacks)
    empty!(session.deregister_callbacks)
    return
end

"""
    send(session::Session; attributes...)

Send values to the frontend via JSON for now
"""
Sockets.send(session::Session; kw...) = send(session, Dict{Symbol, Any}(kw))

function Sockets.send(session::Session, message::Dict{Symbol, Any})
    serialized = SerializedMessage(session, message)
    if session.ignore_message[](message)::Bool
        return
    end
    send(session, serialized)
end

function Sockets.send(session::Session, message::SerializedMessage)
    if isready(session)
        # if connection is open, we should never queue up messages
        @assert isempty(session.message_queue)
        binary = serialize_binary(session, message)
        write(session.connection, binary)
    else
        push!(session.message_queue, message)
    end
end

Base.isopen(session::Session) = isopen(session.connection)

function Base.isready(session::Session)
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
    if error_on_closed && !isopen(session)
        error("Session is not open and would result in this function to indefinitely block.
        It may unblock, if the browser is still connecting and opening the session later on. If this is expected,
        you may try setting `error_on_closed=false`")
    end

    comm = session.js_comm
    comm.val = nothing
    js_with_result = js"""
    try{
        const maybe_promise = $(js);
        // support returning a promise:
        Promise.resolve(maybe_promise).then(result=> {
            $(comm).notify({result});
        })
    }catch(e){
        $(comm).notify({error: e.toString()});
    }
    """

    evaljs(session, js_with_result)
    # TODO, have an on error callback, that triggers when evaljs goes wrong
    # (e.g. because of syntax error that isn't caught by the above try catch!)
    # TODO do this with channels, but we still dont have a way to timeout for wait(channel)... so...
    wait_for(()-> !isnothing(comm[]); timeout=timeout)
    value = comm[]
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

function messages_as_js!(session::Session)
    messages = fused_messages!(session)
    init_messages = if !isempty(messages[:payload])
        b64_str = serialize_string(session, messages)
        return js"""
            (()=> {
                const session_messages = $(b64_str)
                console.log("start loading messages for " + $(session.id))
                JSServe.with_message_lock(()=> {
                    return JSServe.decode_base64_message(session_messages).then(message => {
                        JSServe.process_message(message)
                        console.log("done loading messages for " + $(session.id))
                    })
                })
            })()
        """
    else
        return js""
    end
end


function session_dom(session::Session, dom::Node; init=true, html_document=false)
    # the dom we can render may be anything between a
    # dom fragment or a full page with head & body etc.
    # If we have a head & body, we want to append our initialization
    # code and dom nodes to the right places, so we need to extract those
    head, body, dom = find_head_body(dom)

    # if nothing is found, we just use one div and append to that
    if isnothing(head) && isnothing(body)
        if html_document
            # emit a whole html document
            body_dom = DOM.div(dom, id=session.id, dataJscallId="jsserver-application-dom")
            head = Hyperscript.m("head", Hyperscript.m("meta", charset="UTF-8"), Hyperscript.m("title", "JSServe Application"))
            body = Hyperscript.m("body", body_dom)
            dom = Hyperscript.m("html", head, body)
        else
            # Emit a "fragment"
            application = DOM.div(dom, id=session.id, dataJscallId="jsserver-application-dom")
            head = DOM.div(application)
            dom = head
            body = dom
        end
    end

    init_connection = setup_connection(session)
    if !isnothing(init_connection)
        pushfirst!(children(body), jsrender(session, init_connection))
    end
    init_server = setup_asset_server(session.asset_server)
    if !isnothing(init_server)
        pushfirst!(children(body), jsrender(session, init_server))
    end
    imports = filter(x -> x[2] isa Asset, session.session_objects)
    for (key, asset) in imports
        push!(children(head), jsrender(session, asset))
    end
    issubsession = !isnothing(parent(session))
    if !issubsession
        pushfirst!(children(head), jsrender(session, JSServeLib))
    end

    if init
        run_msg_js = messages_as_js!(session)
        init_messages = js"""
        function init_messages() {
            $(run_msg_js)
        }
        """
        init_session = js"""
            $(init_messages)
            $(JSServeLib).then(J=> J.init_session($(session.id), init_messages, $(issubsession ? "sub" : "root")));
        """
        pushfirst!(children(body), jsrender(session, init_session))
    end

    return dom
end

function render_subsession(p::Session, data)
    return render_subsession(p, DOM.span(data))
end

render_subsession(p::Session, data::Union{AbstractString, Number}) = (p, DOM.span(string(data)))

function render_subsession(parent::Session, app::App)
    sub = Session(parent)
    return sub, session_dom(sub, app; init=false)
end

function render_subsession(parent::Session, dom::Node)
    sub = Session(parent)
    dom_rendered = jsrender(sub, dom)
    return sub, session_dom(sub, dom_rendered; init=false)
end

function update_session_dom!(parent::Session, node_to_update::Union{String, Node}, app_or_dom; replace=true)
    sub, html = render_subsession(parent, app_or_dom)
    # Or we have a node
    id = node_to_update isa String ? node_to_update : uuid(node_to_update)
    str = "[data-jscall-id=$(repr(id))]"
    query_selector = Dict("query_selector" => str)


    if sub === parent # String/Number
        # wrap into observable, so that the whole node gets transfered
        obs = Observable(html)
        evaljs(parent, js"""
            JSServe.Sessions.on_node_available($query_selector, 1).then(dom => {
                const html = $(obs).value
                JSServe.update_or_replace(dom, html, $replace)
            })
        """)
    else
        # We need to manually do the serialization,
        # Since we send it via the parent, but serialization needs to happen
        # for `sub`.
        # sub is not open yet, and only opens if we send the below message for initialization
        # which is why we need to send it via the parent session
        session_update = Dict(
            "msg_type" => "UpdateSession",
            "session_id" => sub.id,
            "messages" => fused_messages!(sub),
            "html" => html,
            "replace" => replace,
            "dom_node_selector" => query_selector
        )
        message = SerializedMessage(sub, session_update)
        send(parent, message)
    end
end
