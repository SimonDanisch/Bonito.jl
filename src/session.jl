
function init_session(session::Session)
    put!(session.js_fully_loaded, true)
    messages = copy(session.message_queue)
    empty!(session.message_queue)
    send(session; msg_type=FusedMessage, payload=messages)
end

function Session(connections::Vector{WebSocket}=WebSocket[]; url_serializer=UrlSerializer(), id=string(uuid4()))
    return Session(
        Ref(false),
        connections,
        Dict{String, Tuple{Bool, Observable}}(),
        Any[],
        Dict{Symbol, Any}[],
        Dict{Asset, Bool}(),
        JSCode[],
        id,
        Channel{Bool}(1),
        init_session,
        url_serializer,
        Ref{Union{Nothing, JSException}}(nothing)
    )
end

session(session::Session) = session

function Base.close(session::Session)
    foreach(close, session.connections)
    empty!(session.connections)
    empty!(session.observables)
    empty!(session.objects)
    empty!(session.on_document_load)
    empty!(session.message_queue)
    empty!(session.dependencies)
end

"""
    queued_as_script(session::Session)

Returns all queued messages as a script that can be included into html
"""
function queued_as_script(session::Session)
    # send all queued messages
    # # first register observables
    observables = Dict{String, Any}()
    for (id, (registered, observable)) in session.observables
        observables[observable.id] = observable[]
    end
    messages = copy(session.message_queue)
    empty!(session.message_queue)
    codes = [session.on_document_load; JSServe.serialize_message_readable.(messages);]
    source, data = JSServe.serialize2string(codes)
    data = Dict("observables" => observables, "payload" => data)
    isdir(dependency_path("session_temp_data")) || mkdir(dependency_path("session_temp_data"))
    deps_path = dependency_path("session_temp_data", session.id * ".msgpack")

    open(io -> MsgPack.pack(io, serialize_js(data)), deps_path, "w")
    data_url = url(Asset(deps_path), session.url_serializer)
    return js"""
        function init_function() {
            $(JSString(source))
        }
        init_from_file(init_function, $(data_url));
    """
end

"""
    send(session::Session; attributes...)

Send values to the frontend via JSON for now
"""
Sockets.send(session::Session; kw...) = send(session, Dict{Symbol, Any}(kw))

global message_counter = Ref(0)

function Sockets.send(session::Session, message::Dict{Symbol, Any})
    message_counter[] += 1
    if isopen(session) && !session.fusing[] && isready(session.js_fully_loaded)
        @assert isempty(session.message_queue)
        for connection in session.connections
            serialize_websocket(connection, message)
        end
    else
        push!(session.message_queue, message)
    end
end

fuse(f, has_session) = fuse(f, session(has_session))
function fuse(f, session::Session)
    oldval = session.fusing[]
    session.fusing[] = true
    result = f()
    session.fusing[] = oldval
    if !isempty(session.message_queue)
        # only sent when open!
        if isopen(session)
            fused = copy(session.message_queue)
            empty!(session.message_queue)
            send(session; msg_type=FusedMessage, payload=fused)
        end
    end
    return result
end

function Base.isopen(session::Session)
    return !isempty(session.connections) && any(isopen, session.connections)
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
        payload=js"return ($(func))"
    )
end

function onjs(has_session, obs::Observable, func::JSCode)
    onjs(session(has_session), obs, func)
end

function on_js_update_observable(session::Session, func::JSCode)
    send(session; msg_type=OnUpdateObservable, payload=func)
end

"""
    onload(session::Session, node::Node, func::JSCode)

calls javascript `func` with node, once node has been displayed.
"""
function onload(session::Session, node::Node, func::JSCode)
    on_document_load(session, js"($(func)).apply(this, [$node]);")
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

function delete_objects(session::Session, objects::Vector{String})
    send(session; msg_type=DeleteObjects, payload=objects)
end

const JS_COMM_CHANNEL = Channel{Dict{String, Any}}(1)
const JS_COMM_OBSERVABLE = Observable(Dict{String, Any}())

"""
    get_js_comm()

Gets the JS communication channels and asserts, that they're in the right state!
"""
function get_js_comm()
    # on first run, we need to register our listener
    if isempty(JS_COMM_OBSERVABLE.listeners)
        # whenever we get a new value, put it in the channel
        on(JS_COMM_OBSERVABLE) do value
            put!(JS_COMM_CHANNEL, value)
        end
    end

    @assert length(JS_COMM_OBSERVABLE.listeners) >= 1
    js_listeners = @view JS_COMM_OBSERVABLE.listeners[2:end]
    # There should be only the listeners needed to forward values to the Frontend!
    @assert all(x-> x isa JSUpdateObservable, js_listeners) "Someone else registered to the comm channel. Nobody should do this!!"
    @assert isopen(JS_COMM_CHANNEL)
    @assert !isready(JS_COMM_CHANNEL) "Channel is still containing a value from another run!"
    return JS_COMM_OBSERVABLE, JS_COMM_CHANNEL
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
    comm, comm_channel = get_js_comm()
    js_with_result = js"""
    try{
        var result = $(js);
        update_obs($(comm), {result: result});
    }catch(e){
        update_obs($(comm), {error: e.toString()});
    }
    """
    evaljs(session, js_with_result)
    # TODO, have an on error callback, that triggers when evaljs goes wrong
    # (e.g. because of syntax error that isn't caught by the above try catch!)
    wait_timeout(()-> isready(comm_channel), "Waited for $(time_out) seconds for JS to return, but it didn't!", time_out)
    value = take!(comm_channel)
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
register_resource!(session::Session, @nospecialize(jss)) = nothing # do nothing for unknown type

function register_resource!(session::Session, list::Union{Tuple, AbstractVector, Pair})
    for elem in list
        register_resource!(session, elem)
    end
end

function register_resource!(session::Session, jss::JSCode)
    register_resource!(session, jss.source)
end

function register_resource!(session::Session, asset::Union{Asset, Dependency, Observable, JSObject})
    push!(session, asset)
end

function register_resource!(session::Session, node::Node)
    walk_dom(session, node) do x
        register_resource!(session, x)
    end
end

function Base.push!(session::Session, observable::Observable)
    if !haskey(session.observables, observable.id)
        session.observables[observable.id] = (true, observable)
        # Register on the JS side by sending the current value
        updater = JSUpdateObservable(session, observable.id)
        # Make sure we update the Javascript values!
        on(updater, observable)
        if isopen(session)
            # If websockets are already open, we need to also update the value
            # to register it with js
            updater(observable[])
        end
    end
end

function Base.push!(session::Session, dependency::Dependency)
    for asset in dependency.assets
        push!(session, asset)
    end
    return dependency
end

function Base.push!(session::Session, asset::Asset)
    if !haskey(session.dependencies, asset)
        session.dependencies[asset] = false
        if asset.onload !== nothing
            on_document_load(session, asset.onload)
        end
    end
    return asset
end

function Base.push!(session::Session, websocket::WebSocket)
    push!(session.connections, websocket)
    filter!(isopen, session.connections)
    return session
end

function Base.push!(session::Session, object::JSObject)
    push!(session.objects, object)
    return object
end

function serialize_message_readable(message)
    type = message[:msg_type]
    if type == UpdateObservable
        return js"        {const value = $(message[:payload]);
                          registered_observables[$(message[:id])] = value;
                          // update all onjs callbacks
                          run_js_callbacks($(message[:id]), value);}"
    elseif type == OnjsCallback
        # we use apply to pass throught the data context
        return js"""        {
                function func() {
                    $(message[:payload])
                }
                register_onjs(func.apply(this), $(message[:id]));
                }
        """
    elseif type == EvalJavascript
        return js"        {$(message[:payload])}"
    elseif type == JSCall
        args = if message[:arguments] isa Tuple
            if isempty(message[:arguments])
                JSString("")
            else
                args = []
                for arg in message[:arguments][1:end-1]
                    push!(args, arg)
                    push!(args, JSString(", "))
                end
                push!(args, message[:arguments][end])
                JSCode(args)
            end
        else
            message[:arguments]
        end
        return js"        put_on_heap($(message[:result]), $(message[:func])($(args)));"
    elseif type == JSGetIndex
        return js"        get_js_index($(message[:object]), $(message[:field]), $(message[:result]));"
    elseif type == JSSetIndex
        return js"        $(message[:object])[$(message[:field])] = $(message[:value]);"
    elseif type == FusedMessage
        return JSCode(serialize_message_readable.(message[:payload]))
    elseif type == DeleteObjects
        return js"        delete_heap_objects($(message[:payload]));"
    elseif type == OnUpdateObservable
        return js"""        {
                const func = $(message[:payload]);
                on_update_observables_callbacks.push(func);
                };
        """

    else
        error("type not found: $(type)")
    end
end
