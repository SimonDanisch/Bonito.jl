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

function init_session(session::Session)
    println("initing session :)")
    put!(session.connection_ready, true)
    send(session, fused_messages!(session))
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
function add_cached!(create_cached_object::Function, session::Session, message_cache::Dict{String, Any}, key::String)
    # If already in session, there's nothing we need to do, since we've done the work the first time we added the object
    haskey(session.session_cache, key) && return nothing
    # Now, we have two code paths, depending on whether we have a child session or a root session
    root = root_session(session)
    if root === session # we are root, so we simply cache the object (we already checked it's not cached yet)
        obj = create_cached_object()
        message_cache[key] = obj
        session.session_cache[key] = obj
        return obj # we need to send the object to JS, so we return it here
    else
        # This session is a child session.
        # We never cache objects in the child directly, but track it here with `key => nothing` for cleaning up purposes.
        session.session_cache[key] = nothing
        # Now we need to figure out if the root session has the object cached already
        # The root session has our object cached already.
        if haskey(root.session_cache, key)
            # in this case, we just add the key to the message cache, so that the JS side can associate the object with out session
            message_cache[key] = nothing
            return nothing
        end
        # Nobody has the object cached
        obj = create_cached_object()
        message_cache[key] = obj
        root.session_cache[key] = obj
        return obj
    end
end


function child_haskey(child::Session, key)
    haskey(child.session_cache, key) && return true
    return any(((id, s),)-> child_haskey(s, key), child.children)
end

function delete_cached!(root::Session, key::String)
    if !haskey(session.session_cache, key)
        # This should uncover any fault in our caching logic!
        error("Deleting key that doesn't belong to any cached object")
    end
    # We don't do reference counting, but we check if any child still holds a reference to the object we want to delete
    if !any(((id, s),)-> child_haskey(s, key), root.children)
        # So only delete it if nobody has it anymore!
        delete!(session.session_cache, key)
    end
end

function Base.close(session::Session)
    # unregister all cached objects from parent session
    root = root_session(session)
    # If we're a child session, we need to remove all objects trackt in our root session:
    if session !== root
        # We need to remove our session from the parent first, otherwise `delete_cached!`
        # will think our session still holds the value, which would prevent it from deleting
        delete!(parent(session), session.id)
        for key in keys(session.session_cache)
            delete_cached!(root, key)
        end
    end
    # delete_cached! only deletes in the root session so we need to still empty the session_cache:
    empty!(session.session_cache)

    close(session.connection)
    empty!(session.observables)
    empty!(session.on_document_load)
    empty!(session.message_queue)
    empty!(session.session_cache)
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
    if isready(session)
        @assert isempty(session.message_queue)
        binary = serialize_binary(session, message)
        write(session.connection, binary)
    else
        push!(session.message_queue, message)
    end
end

function Base.isready(session::Session)
    return isready(session.connection_ready) && isopen(session)
end

Base.isopen(session::Session) = isopen(session.connection)

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

"""
    register_resource!(session::Session, domlike)

Walks dom like structures and registers all resources (Observables, Assets Depencies)
with the session.
"""
register_resource!(session::Session, @nospecialize(obj), resources=nothing) = nothing # do nothing for unknown type

function register_resource!(session::Session, list::Union{Tuple, AbstractVector, Pair}, resources=nothing)
    for elem in list
        register_resource!(session, elem, resources)
    end
end

function register_resource!(session::Session, dict::Union{NamedTuple, AbstractDict}, resources=nothing)
    for (k, v) in pairs(dict)
        register_resource!(session, v, resources)
        register_resource!(session, k, resources)
    end
end

function register_resource!(session::Session, jss::JSCode, resources=nothing)
    register_resource!(session, jss.source, resources)
end

function register_resource!(session::Session, node::Node, resources=nothing)
    walk_dom(node) do x
        register_resource!(session, x, resources)
    end
end

function register_resource!(session::Session, observable::Observable, resources=nothing)
    if !haskey(session.observables, observable.id)
        session.observables[observable.id] = (true, observable)
        # Register on the JS side by sending the current value
        updater = JSUpdateObservable(session, observable.id)
        on(updater, session, observable)
        # Make sure we register on the js side
        send(session, payload=observable[], id=observable.id, msg_type=RegisterObservable)
    end
end

function register_resource!(session::Session, asset::Asset, resources=nothing)
    isnothing(resources) || push!(resources, asset)
    push!(session.dependencies, asset)
    return asset
end

function session_dom(session::Session, app::App)
    dom = jsrender(session, app.handler(session, (target="/",)))
    body = nothing
    head = nothing
    walk_dom(dom) do x
        x isa Node || return
        t = Hyperscript.tag(x)
        if t == "body"
            body = x
        elseif t == "head"
            head = x
        end
        !isnothing(body) && !isnothing(head) && return Break()
    end

    if isnothing(head) && isnothing(body)
        body = dom
        head = dom
        dom = DOM.div(dom, id=session.id)
    end

    init_connection = jsrender(session, JSServe.setup_connect(session))
    init_server = jsrender(session, JSServe.setup_asset_server(session.asset_server))

    # TODO, just sent them once connection opens?
    all_messages = fused_messages!(session)
    issubsession = !isnothing(parent(session))
    on_open = if !isempty(all_messages)
        msg_b64_str = serialize_string(session, all_messages)
        """
            const all_messages = `$(msg_b64_str)`
            return JSServe.decode_base64_message(all_messages).then(JSServe.process_message)
        """
    else
        ""
    end

    init_session = """
    function on_connection_open(){
    $(on_open)
    }
    JSServe.init_session('$(session.id)', on_connection_open, $(issubsession));
    """
    js = []
    if !issubsession
        push!(js, jsrender(session, JSServeLib))
    end
    push!(js, DOM.script(init_session, type="module"), init_connection, init_server)
    pushfirst!(children(head), js...)
    return dom
end
