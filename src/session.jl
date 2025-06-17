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
    evaljs(session, js"""
        const application_dom = document.getElementById('application-dom')
        if (application_dom) {
            application_dom.style.visibility = 'visible'
        }
    """)
    put!(session.js_fully_loaded, true)
    send(session, fused_messages!(session))
end

function Session(connection=Base.RefValue{Union{WebSocket, Nothing, IOBuffer}}(nothing); url_serializer=UrlSerializer(), id=string(uuid4()))
    return Session(
        connection,
        Dict{String, Tuple{Bool, Observable}}(),
        Dict{Symbol, Any}[],
        Set{Asset}(),
        JSCode[],
        id,
        Channel{Bool}(1),
        init_session,
        url_serializer,
        Ref{Union{Nothing, JSException}}(nothing),
        Observable{Union{Nothing, Dict{String, Any}}}(nothing),
        Observable(false),
        Observables.ObserverFunction[],
        Dict{String, WeakRef}()
    )
end

function Session(session::Session;
                connection=session.connection,
                observables=session.observables,
                message_queue=session.message_queue,
                dependencies=session.dependencies,
                on_document_load=session.on_document_load,
                id=session.id,
                js_fully_loaded=session.js_fully_loaded,
                on_websocket_ready=session.on_websocket_ready,
                url_serializer=session.url_serializer,
                init_error=session.init_error,
                js_comm=session.js_comm,
                on_close=session.on_close,
                deregister_callbacks=session.deregister_callbacks,
                unique_object_cache=session.unique_object_cache)
    return Session(
        connection,
        observables,
        message_queue,
        dependencies,
        on_document_load,
        id,
        js_fully_loaded,
        on_websocket_ready,
        url_serializer,
        init_error,
        js_comm,
        on_close,
        deregister_callbacks,
        unique_object_cache
    )
end

session(session::Session) = session

function Base.close(session::Session)
    try
        # https://github.com/JuliaWeb/HTTP.jl/issues/649
        if isassigned(session.connection) && !isnothing(session.connection[])
            close(session.connection[])
        end
    catch e
        if !(e isa Base.IOError)
            @warn "error while closing websocket!" exception=e
        end
    end
    try
        # Errors in `on_close` should not disrupt closing!
        session.on_close[] = true
    catch e
        @warn "error while setting on_close" exception=e
    end
    empty!(session.observables)
    empty!(session.on_document_load)
    empty!(session.message_queue)
    empty!(session.dependencies)
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
        write(session.connection[], binary)
    else
        push!(session.message_queue, message)
    end
end

function Base.isready(session::Session)
    return isready(session.js_fully_loaded) && isopen(session)
end

function Base.isopen(session::Session)
    return isassigned(session.connection) && !isnothing(session.connection[]) && isopen(session.connection[])
end

"""
    onjs(session::Session, obs::Observable, func::JSCode)

Register a javascript function with `session`, that get's called when `obs` gets a new value.
If the observable gets updated from the JS side, the calling of `func` will be triggered
entirely in javascript, without any communication with the Julia `session`.
"""
function onjs(session::Session, obs::Observable, func::JSCode)
    # register the callback with the JS session
    register_resource!(session, (obs, func))
    send(
        session;
        msg_type=OnjsCallback,
        id=obs.id,
        payload=JSCode([JSString("return "), func])
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
    on_document_load(session, js"($(func))($(node));")
end

"""
    on_document_load(session::Session, js::JSCode)

executes javascript after document is loaded
"""
function on_document_load(session::Session, js::JSCode)
    register_resource!(session, js)
    push!(session.on_document_load, js)
end

"""
    linkjs(session::Session, a::Observable, b::Observable)

for an open session, link a and b on the javascript side. This will also
Link the observables in Julia, but only as long as the session is active.
"""
function linkjs(session::Session, a::Observable, b::Observable)
    # register the callback with the JS session
    onjs(session, a, js"(v) => JSServe.update_obs($b, v)")
end

function linkjs(has_session, a::Observable, b::Observable)
    linkjs(session(has_session), a, b)
end

"""
    evaljs(session::Session, jss::JSCode)

Evaluate a javascript script in `session`.
"""
function evaljs(session::Session, jss::JSCode)
    register_resource!(session, jss)
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
        console.log(result)
        JSServe.update_obs($(comm), {result: result});
    }catch(e){
        JSServe.update_obs($(comm), {error: e.toString()});
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
register_resource!(session::Session, @nospecialize(obj)) = nothing # do nothing for unknown type

function register_resource!(session::Session, list::Union{Tuple, AbstractVector, Pair})
    for elem in list
        register_resource!(session, elem)
    end
end

function register_resource!(session::Session, dict::Union{NamedTuple, AbstractDict})
    for (k, v) in pairs(dict)
        register_resource!(session, v)
        register_resource!(session, k)
    end
end

function register_resource!(session::Session, jss::JSCode)
    register_resource!(session, jss.source)
end

function register_resource!(session::Session, asset::Union{Asset, Dependency, Observable})
    push!(session, asset)
end

function register_resource!(session::Session, node::Node)
    walk_dom(node) do x
        register_resource!(session, x)
    end
end

function Base.push!(session::Session, observable::Observable)
    if !haskey(session.observables, observable.id)
        session.observables[observable.id] = (true, observable)
        # Register on the JS side by sending the current value
        updater = JSUpdateObservable(session, observable.id)
        on(updater, session, observable)
        # Make sure we register on the js side
        send(session, payload=observable[], id=observable.id, msg_type=RegisterObservable)
    end
end

function Base.push!(session::Session, dependency::Dependency)
    for asset in dependency.assets
        push!(session, asset)
    end
    return dependency
end

function Base.push!(session::Session, asset::Asset)
    push!(session.dependencies, asset)
    if asset.onload !== nothing
        on_document_load(session, asset.onload)
    end
    return asset
end
