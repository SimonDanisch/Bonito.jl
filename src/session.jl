
function init_session(session::Session)
    for msg in session.message_queue
        for connection in session.connections
            serialize_websocket(connection, msg)
        end
    end
    empty!(session.message_queue)
    notify(session.js_fully_loaded)
end

function Session(connections::Vector{WebSocket}=WebSocket[])
    Session(
        Ref(false),
        connections,
        Dict{String, Tuple{Bool, Observable}}(),
        Dict{Symbol, Any}[],
        Set{Asset}(),
        JSCode[],
        string(uuid4()),
        Base.Event(),
        init_session
    )
end

function Base.close(session::Session)
    foreach(close, session.connections)
    empty!(session.connections)
    empty!(session.observables)
    empty!(session.on_document_load)
    empty!(session.message_queue)
    empty!(session.dependencies)
end

function Base.copy(session::Session)
    obs = Dict((k => (true, map(identity, obs)) for (k, (regs, obs)) in session.observables))
    return Session(
        WebSocket[],
        session.observables,
        Dict{Symbol, Any}[],
        copy(session.dependencies),
        JSCode[]
    )
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
    for (name, jscode) in dependency.functions
        push!(session.on_document_load, JSCode([JSString("$name = "), jscode.source...]))
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

function Base.push!(session::Session, websocket::WebSocket)
    push!(session.connections, websocket)
    filter!(isopen, session.connections)
    return session
end


"""
    queued_as_script(session::Session)

Returns all queued messages as a script that can be included into html
"""
function queued_as_script(io::IO, session::Session)
    # send all queued messages
    # # first register observables
    observables = Dict{String, Any}()

    for (id, (registered, observable)) in session.observables
        observables[observable.id] = observable[]
    end

    data = Dict("observables" => observables, "messages" => session.message_queue)

    isdir(dependency_path("session_temp_data")) || mkdir(dependency_path("session_temp_data"))

    deps_path = dependency_path("session_temp_data", session.id * ".msgpack")
    open(io -> MsgPack.pack(io, serialize_js(data)), deps_path, "w")
    data_url = url(AssetRegistry.register(deps_path))
    println(io, js"""
    var url = $(data_url);

    var http_request = new XMLHttpRequest();
    http_request.open("GET", url, true);
    http_request.responseType = "arraybuffer";
    var t0 = performance.now();
    http_request.onload = function (event) {
        var t1 = performance.now();
        console.log("download done! " + (t1 - t0) + " milliseconds.");
        var arraybuffer = http_request.response; // Note: not oReq.responseText
        if (arraybuffer) {
            var bytes = new Uint8Array(arraybuffer);
            var data = msgpack.decode(bytes);
            for (let obs_id in data.observables) {
                registered_observables[obs_id] = data.observables[obs_id];
            }
            for (let message in data.messages) {
                process_message(data.messages[message]);
            }
            t1 = performance.now();
            console.log("msg process done! " + (t1 - t0) + " milliseconds.");
            websocket_send({msg_type: JSDoneLoading});
        }else{
            send_warning("Didn't receive any setup data from server.")
        }
    };
    http_request.send(null);
    """)
    empty!(session.message_queue)
end

queued_as_script(session::Session) = sprint(io-> queued_as_script(io, session))

"""
    send(session::Session; attributes...)

Send values to the frontend via JSON for now
"""
Sockets.send(session::Session; kw...) = send(session, Dict{Symbol, Any}(kw))

function Sockets.send(session::Session, message::Dict{Symbol, Any})
    if isopen(session) && !session.fusing[]
        for connection in session.connections
            serialize_websocket(connection, message)
        end
    else
        push!(session.message_queue, message)
    end
end

fuse(f, has_session) = fuse(f, session(has_session))
function fuse(f, session::Session)
    session.fusing[] = true
    result = f()
    session.fusing[] = false
    if !isempty(session.message_queue)
        send(session; msg_type=FusedMessage, payload=session.message_queue)
        empty!(session.message_queue)
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
        session,
        msg_type = OnjsCallback,
        id = obs.id,
        # eval requires functions to be wrapped in ()
        payload = js"($func)"
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
    on_document_load(session, js"""
        ($(func))($node);
    """)
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
    onjs(
        session,
        a,
        js"""
        function (value){
            // update_obs will return false once b is gone,
            // so this will automatically deregister the link!
            return update_obs($b, value)
        }
        """
    )
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
    send(session, msg_type = EvalJavascript, payload = jss)
end

function evaljs(has_session, jss::JSCode)
    evaljs(session(has_session), jss)
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
function evaljs_value(session::Session, js, error_on_closed=true)
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
        update_obs($(comm), {error: JSON.stringify(e)});
    }
    """
    evaljs(session, js_with_result)
    value = take!(comm_channel)
    if haskey(value, "error")
        error(value["error"])
    else
        return value["result"]
    end
end

"""
    active_sessions(app::Application)

Returns all active sessions of an Application
"""
function active_sessions(app::Application)
    collect(filter(app.sessions) do (k, v)
        any(x-> isopen(x[2]), v) # leave not yet started connections
    end)
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

function register_resource!(session::Session, asset::Union{Asset, Dependency, Observable})
    push!(session, asset)
end

function register_resource!(session::Session, node::Node)
    walk_dom(session, node) do x
        register_resource!(session, x)
    end
end


function update_dom!(session::Session, dom)
    # empty!(session.on_document_load)
    dom = jsrender(session, dom)
    register_resource!(session, dom)
    innerhtml = repr(MIME"text/html"(), dom)
    new_deps = session.dependencies
    new_jss = JSCode(Any[])
    for jss in session.on_document_load
        append_source!(new_jss, jss)
    end
    register_obs!(session)
    script_urls = url.(new_deps)
    update_script = js"""
        var dom = document.getElementById('application-dom')
        dom.innerHTML = $(innerhtml)
        var urls = $(script_urls)
        for (var i = 0; i < urls.length; i++) {
            var s = document.createElement("script");
            s.type = "text/javascript";
            s.async = false
            s.src = urls[i];
            document.head.appendChild(s);
        }
        var s = document.createElement("script");
        s.type = "text/javascript";
        s.async = false
        s.text = $(serialize_readable(new_jss));
        document.head.appendChild(s);
    """
    println(serialize_readable(update_script))
    evaljs(session, update_script)
end
