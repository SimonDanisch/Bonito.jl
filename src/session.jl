
function Session(connection = Ref{WebSocket}())
    Session(
        connection,
        Dict{String, Tuple{Bool, Observable}}(),
        Dict{Symbol, Any}[],
        Set{Asset}(),
        JSCode[]
    )
end

function Base.close(session::Session)
    isopen(session) && close(session.connection[])
    empty!(session.observables)
    empty!(session.on_document_load)
    empty!(session.message_queue)
    empty!(session.dependencies)
end

function Base.push!(session::Session, x::Observable)
    session.observables[x.id] = (false, x)
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

"""
    send_queued(session::Session)

Sends all queued operations to the frontend
"""
function send_queued(session::Session)
    if isopen(session)
        # send all queued messages
        for message in session.message_queue
            send(session, message)
        end
        empty!(session.message_queue)
    else
        error("To send queued messages make sure that session is open.")
    end
end



"""
    queued_as_script(session::Session)

Returns all queued messages as a script that can be included into a html
"""
function queued_as_script(io::IO, session::Session)
    # send all queued messages
    # first register observables
    for (id, (registered, observable)) in session.observables
        if !registered
            # Register on the JS side by sending the current value
            updater = JSUpdateObservable(session, id)
            # Make sure we update the Javascript values!
            on(updater, observable)
            session.observables[id] = (true, observable)
            serialize_string(io, js"    registered_observables[$(observable)] = $(observable[]);")
            println(io)
        end
    end
    for message in session.message_queue
        serialize_string(
            io,
            js"    process_message(deserialize_js($(AsJSON(message))));"
        )
        println(io)
    end
    empty!(session.message_queue)
end
queued_as_script(session::Session) = sprint(io-> queued_as_script(io, session))

"""
    send(session::Session; attributes...)

Send values to the frontend via JSON for now
"""
Sockets.send(session::Session; kw...) = send(session, Dict{Symbol, Any}(kw))


function Sockets.send(session::Session, message::Dict{Symbol, Any})
    if isopen(session)
        # send all queued messages
        # send_queued(session)
        # sent the actual message
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
        session,
        type = OnjsCallback,
        id = obs.id,
        # eval requires functions to be wrapped in ()
        payload = js"($func)"
    )
end


"""
    onload(session::Session, node::Node, func::JSCode)

calls javascript `func` with node, once node has been displayed.
"""
function onload(session::Session, node::Node, func::JSCode)
    on_document_load(session, js"""
        // on document load, call func with the node
        ($(func))($node)
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

"""
    evaljs(session::Session, jss::JSCode)

Evaluate a javascript script in `session`.
"""
function evaljs(session::Session, jss::JSCode)
    register_resource!(session, jss)
    send(session, type = EvalJavascript, payload = jss)
end

"""
    active_sessions(app::Application)

Returns all active sessions of an Application
"""
function active_sessions(app::Application)
    collect(filter(app.sessions) do (k, v)
        isopen(v) # leave not yet started connections
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
        s.text = $(serialize_string(new_jss));
        document.head.appendChild(s);
    """
    println(serialize_string(update_script))
    evaljs(session, update_script)
end
