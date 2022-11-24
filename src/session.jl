function fused_messages!(session::Session)
    messages = []
    append!(messages, session.message_queue)
    for js in session.on_document_load
        push!(messages, Dict(:msg_type=>EvalJavascript, :payload=>js))
    end
    empty!(session.on_document_load)
    empty!(session.message_queue)
    return Dict(:msg_type=>FusedMessage, :payload=>messages)
end

open!(connection) = nothing

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


"""
    add_cached!(create_cached_object::Function, session::Session, message_cache::Dict{String, Any}, key::String)

Checks if key is already cached by the session or it's root session (we skip any child session between root -> this session).
If not cached already, we call `create_cached_object` to create a serialized form of the object corresponding to `key` and cache it.
We return nothing if already cached, or the serialized object if not cached.
We also handle the part of adding things to the message_cache from the serialization context.
"""
function add_cached!(create_cached_object::Function, session::Session, send_to_js::Dict{String, Any}, @nospecialize(object))
    key = object_identity(object)::String
    result = js_type("CacheKey", key)
    # If already in session, there's nothing we need to do, since we've done the work the first time we added the object
    haskey(session.session_objects, key) && return result
    # Now, we have two code paths, depending on whether we have a child session or a root session
    root = root_session(session)
    if root === session # we are root, so we simply cache the object (we already checked it's not cached yet)
        send_to_js[key] = create_cached_object()
        session.session_objects[key] = object
        return result
    else
        # This session is a child session.

        # Now we need to figure out if the root session has the object cached already
        # The root session has our object cached already.
        session.session_objects[key] = nothing # session needs to reference this to "own" it
        if haskey(root.session_objects, key)
            # in this case, we just add the key to send to js, so that the JS side can associate the object with this session
            send_to_js[key] = "tracking-only"
            return result
        end
        # Nobody has the object cached, so we
        # we add this session as the owner, but also add it to the root session
        send_to_js[key] = create_cached_object()
        root.session_objects[key] = object
        return result
    end
end

function child_haskey(child::Session, key)
    haskey(child.session_objects, key) && return true
    return any(((id, s),)-> child_haskey(s, key), child.children)
end

function delete_cached!(root::Session, key::String)
    if !haskey(root.session_objects, key)
        # This should uncover any fault in our caching logic!
        error("Deleting key that doesn't belong to any cached object")
    end
    # We don't delete assets for now (since they remain loaded on the page anyways)
    # And of course not Retain, since that's the whole point of it
    root.session_objects[key] isa Union{Retain, Asset} && return
    # We don't do reference counting, but we check if any child still holds a reference to the object we want to delete
    has_ref = any(((id, s),)-> child_haskey(s, key), root.children)
    if !has_ref
        # So only delete it if nobody has it anymore!
        delete!(root.session_objects, key)
    end
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
    unregister_session!(session)
    return
end

"""
    send(session::Session; attributes...)

Send values to the frontend via JSON for now
"""
Sockets.send(session::Session; kw...) = send(session, Dict{Symbol, Any}(kw))

function Sockets.send(session::Session, message::Dict{Symbol, Any})
    if isready(session)
        # if connection is open, we should never queue up messages
        @assert isempty(session.message_queue)
        binary = serialize_binary(session, message)
        write(session.connection, binary)
    else
        push!(session.message_queue, message)
    end
end

function send_serialized(session::Session, serialized_message::Dict{Symbol, Any})
    if isready(session)
        @assert isempty(session.message_queue)
        binary = transcode(GzipCompressor, MsgPack.pack(serialized_message))
        write(session.connection, binary)
    else
        push!(session.message_queue, serialized_message)
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
function evaljs_value(session::Session, js; error_on_closed=true, time_out=10.0)
    if error_on_closed && !isopen(session)
        error("Session is not open and would result in this function to indefinitely block.
        It may unblock, if the browser is still connecting and opening the session later on. If this is expected,
        you may try setting `error_on_closed=false`")
    end

    comm = session.js_comm
    comm.val = nothing
    js_with_result = js"""
    try{
        const result = $(js);
        $(comm).notify({result: result});
    }catch(e){
        $(comm).notify({error: e.toString()});
    }
    """

    evaljs(session, js_with_result)
    # TODO, have an on error callback, that triggers when evaljs goes wrong
    # (e.g. because of syntax error that isn't caught by the above try catch!)

    tstart = time()
    while (time() - tstart < time_out) && isnothing(comm[])
        yield()
    end
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

function evaljs_value(with_session, js; error_on_closed=true, time_out=100.0)
    evaljs_value(session(with_session), js; error_on_closed=error_on_closed, time_out=time_out)
end

function rendered_dom(session::Session, app::App, target=(; target="/"))
    app.session[] = session
    dom = Base.invokelatest(app.handler, session, target)
    return jsrender(session, dom)
end

function session_dom(session::Session, app::App; init=true)
    dom = rendered_dom(session, app)
    return session_dom(session, dom; init=init)
end



function session_dom(session::Session, dom::Node; init=true)
    # the dom we can render may be anything between a
    # dom fragment or a full page with head & body etc.
    # If we have a head & body, we want to append our initialization
    # code and dom nodes to the right places, so we need to extract those
    head, body, dom = find_head_body(dom)

    # if nothing is found, we just use one div and append to that
    if isnothing(head) && isnothing(body)
        body = dom
        head = dom
        dom = DOM.div(dom, id=session.id)
    end

    init_connection = setup_connection(session)
    init_server = setup_asset_server(session.asset_server)

    issubsession = !isnothing(parent(session))
    js = []
    if !issubsession
        push!(js, jsrender(session, JSServeLib))
    end

    if init
        init_session = js"""
        JSServe.init_session($(session.id), ()=> null, $(issubsession ? "sub" : "root"));
        """
        push!(js, jsrender(session, init_session))
    end

    if !isnothing(init_connection)
        push!(js, jsrender(session, init_connection))
    end

    if !isnothing(init_server)
        push!(js, jsrender(session, init_server))
    end
    #
    pushfirst!(children(head), js...)
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

function update_session_dom!(parent::Session, node_to_update::Union{String, Node}, app_or_dom)
    sub, html = render_subsession(parent, app_or_dom)

    if node_to_update isa String # session id of old session to update
        query_selector = Dict("by_id" => node_to_update)
    else
        # Or we have a node
        str = "[data-jscall-id=$(repr(uuid(node_to_update)))]"
        query_selector = Dict("query_selector" => str)
    end

    if sub === parent # String/Number
        # wrap into observable, so that the whole node gets transfered
        obs = Observable(html)
        evaljs(parent, js"""
            JSServe.Sessions.on_node_available($query_selector, 1).then(dom => {
                while (dom.firstChild) {
                    dom.removeChild(dom.lastChild);
                }
                dom.append($(obs).value)
            })
        """)
    else
        session_data = Dict(
            :messages => fused_messages!(sub),
            :html => html
        )
        ctx = SerializationContext(sub)
        data = serialize_cached(ctx, session_data)
        message = Dict(
            :session_id => sub.id,
            :data => data,
            :cache => ctx.message_cache,
            :dom_node_selector => query_selector
        )
        send_serialized(parent, message)
    end
end

function update_app!(old_app::App, new_app::App)
    if isnothing(old_app.session[])
        error("Old app has to be displayed first, to actually update it")
    end
    old_session = old_app.session[]
    parent = root_session(old_session)
    update_session_dom!(parent, old_session.id, new_app)
end
