
function init_session(session::Session)
    put!(session.js_fully_loaded, true)
    messages = []
    for (id, (reg, obs)) in session.observables
        push!(messages, Dict(:msg_type=>UpdateObservable, :payload=>obs[], :id=>obs.id))
    end
    append!(messages, session.message_queue)
    for js in session.on_document_load
        push!(messages, Dict(:msg_type=>EvalJavascript, :payload=>js))
    end
    empty!(session.message_queue)
    send(session; msg_type=FusedMessage, payload=messages)
end

function Session(connection::Base.RefValue{WebSocket}=Base.RefValue{WebSocket}(); url_serializer=UrlSerializer(), id=string(uuid4()))
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
        Observables.ObserverFunction[]
    )
end

session(session::Session) = session

function Base.close(session::Session)
    try
        # https://github.com/JuliaWeb/HTTP.jl/issues/649
        close(session.connection[])
    catch e
        if !(e isa Base.IOError)
            @warn "error while closing websocket!" exception=e
        end
    finally
        session.connection[].rxclosed = true
    end

    session.on_close[] = true
    empty!(session.observables)
    empty!(session.on_document_load)
    empty!(session.message_queue)
    empty!(session.dependencies)
    # remove all listeners that where created for this session
    foreach(off, session.deregister_callbacks)
end

"""
    send(session::Session; attributes...)

Send values to the frontend via JSON for now
"""
Sockets.send(session::Session; kw...) = send(session, Dict{Symbol, Any}(kw))

function Sockets.send(session::Session, message::Dict{Symbol, Any})
    if isopen(session) && isready(session.js_fully_loaded)
        @assert isempty(session.message_queue)
        serialize_websocket(session.connection[], message)
    else
        push!(session.message_queue, message)
    end
end

function Base.isopen(session::Session)
    return isassigned(session.connection) && isopen(session.connection[])
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
    onjs(session, a, js"(v) => update_obs($b, v)")
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
function evaljs_value(session::Session, js; error_on_closed=true, time_out=100.0)
    if error_on_closed && !isopen(session)
        error("Session is not open and would result in this function to indefinitely block.
        It may unblock, if the browser is still connecting and opening the session later on. If this is expected,
        you may try setting `error_on_closed=false`")
    end

    comm = session.js_comm
    comm.value = nothing
    js_with_result = js"""
    try{
        const result = $(js);
        update_obs($(comm), {result: result});
    }catch(e){
        update_obs($(comm), {error: e.toString()});
    }
    """

    evaljs(session, js_with_result)
    # TODO, have an on error callback, that triggers when evaljs goes wrong
    # (e.g. because of syntax error that isn't caught by the above try catch!)
    result = Base.timedwait(()-> comm[] !== nothing, time_out)
    result == :time_out && error("Waited for $(time_out) seconds for JS to return, but it didn't!")
    value = comm[]
    if haskey(value, "error")
        error(value["error"])
    else
        return value["result"]
    end
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
        # Make sure we update the Javascript values!
        on(updater, session, observable)
        updater(observable[])
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
