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
    put!(session.connection_ready, true)
    send(session, fused_messages!(session))
end

function Session(connection=default_connect();
                id=string(uuid4()),
                asset_server=default_asset_server(),
                observables=Dict{String, Observable}(),
                message_queue=Dict{Symbol, Any}[],
                on_document_load=JSCode[],
                connection_ready=Channel{Bool}(1),
                on_connection_ready=init_session,
                init_error=Ref{Union{Nothing, JSException}}(nothing),
                js_comm=Observable{Union{Nothing, Dict{String, Any}}}(nothing),
                on_close=Observable(false),
                deregister_callbacks=Observables.ObserverFunction[],
                session_cache=Dict{String, Any}())

    return Session(
        id,
        connection,
        asset_server,
        observables,
        message_queue,
        on_document_load,
        connection_ready,
        on_connection_ready,
        init_error,
        js_comm,
        on_close,
        deregister_callbacks,
        session_cache
    )
end

session(session::Session) = session

function Base.close(session::Session)
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
        write(session.connection[], binary)
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
        update_obs($(comm), {result: result});
    }catch(e){
        update_obs($(comm), {error: e.toString()});
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

# path = JSServe.dependency_path("JSServe.js")
# bundled = joinpath(dirname(path), "JSServe.bundle.js")
# Deno_jll.deno() do exe
#     write(bundled, read(`$exe bundle $(path)`))
# end


function session_dom(session::Session, app::App)
    dom = jsrender(session, app.handler(session, (target="/",)))
    all_messages = fused_messages!(session)
    msg_b64_str = serialize_string(session, all_messages)
    connection_init = JSServe.setup_connect(session)
    asset_init = JSServe.setup_asset_server(session.asset_server)
    init = """
        const all_messages = $(repr(msg_b64_str))
        JSServe.init_session({all_messages, session_id: '$(session.id)'});
    """
    return DOM.div(
        jsrender(session, JSServeLib),
        DOM.script(init, type="module"),
        jsrender(session, connection_init),
        dom,
        id=session.id,
        style="visibility: hidden;"
    )
end
