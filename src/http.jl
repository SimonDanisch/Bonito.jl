# Save some bytes by using ints for switch variable
const UpdateObservable = "0"
const OnjsCallback = "1"
const EvalJavascript = "2"
const JavascriptError = "3"
const JavascriptWarning = "4"

const JSCall = "5"
const JSGetIndex = "6"
const JSSetIndex = "7"

function request_to_sessionid(request; throw = true)
    if length(request.target) >= 36 # for /id/
        sessionid = split(request.target, "/", keepempty = false)[end] # remove the '/' id '/'
        if length(sessionid) == 36
            return string(sessionid)
        end
    end
    if throw
        error("Invalid sessionid: $(request.target)")
    else
        return nothing
    end
end

function dom2html(session::Session, sessionid::String, dom)
    return sprint() do io
        dom2html(io, session, sessionid, dom)
    end
end

function dom2html(io::IO, session::Session, sessionid::String, dom)
    js_dom = jsrender(session, dom)
    html = repr(MIME"text/html"(), js_dom)

    register_resource!(session, js_dom)

    print(io, """
        <html>
        <head>
        """
    )
    # Insert all script/css dependencies into the header
    serialize_string(io, session.dependencies)
    # insert the javascript for JSCall
    print(io, """
        <script>
            window.js_call_session_id = '$(sessionid)';
        """)
    if !isempty(server_proxy_url[])
        print(io, """
            window.websocket_proxy_url = '$(server_proxy_url[])';
        """)
    end
    println(io, """
        function __on_document_load__(){
    """)
    # create a function we call in body onload =, which loads all
    # on_document_load javascript
    serialize_string(io, session.on_document_load)
    queued_as_script(io, session)
    print(io, """
        };
        </script>
        """
    )
    serialize_string(io, JSCallLib)
    print(io, """
        </head>
        <body"""
    )
    # insert on document load
    print(io, " onload = '__on_document_load__()'")
    print(io, """>
        <div id='application-dom'>
        """
    )
    println(io, html, "\n</div>")
    print(io, """
        </body>
        </html>
        """
    )
end

include("mimetypes.jl")

function http_handler(application::Application, request::Request)
    try
        if haskey(AssetRegistry.registry, request.target)
            filepath = AssetRegistry.registry[request.target]
            if isfile(filepath)
                return HTTP.Response(
                    200,
                    [
                        "Access-Control-Allow-Origin" => "*",
                        "Content-Type" => file_mimetype(filepath)
                    ],
                    body = read(filepath)
                )
            else
                return HTTP.Response(404)
            end
        else
            body = if applicable(application.dom, request)
                # Inline display handling
                sessionid_dom = Base.invokelatest(application.dom, request)
                if sessionid_dom === nothing
                    "No route for request: $(request.target)" # request for e.g. favicon etc
                else
                    # request that corresponds to getting a session
                    sessionid, dom = sessionid_dom
                    session = application.sessions[sessionid]
                    dom2html(session, sessionid, dom)
                end
            else
                if request.target == "/"
                    sessionid = string(uuid4())
                    session = Session(Ref{WebSocket}())
                    application.sessions[sessionid] = session
                    dom = Base.invokelatest(application.dom, session, request)
                    dom2html(session, sessionid, dom)
                else
                    "No route for request: $(request.target)"
                end
            end
            return HTTP.Response(
                200,
                ["Content-Type" => "text/html"],
                body = body
            )
        end
    catch e
        @warn "error in handler" exception=e
        return "error :(\n$e"
    end
end

"""
    handle_ws_message(session::Session, message)

Handles the incoming websocket messages from the frontend
"""
function handle_ws_message(session::Session, message)
    isempty(message) && return
    data = JSON3.read(String(message))
    typ = data["type"]
    if typ == UpdateObservable
        registered, obs = session.observables[data["id"]]
        @assert registered # must have been registered to come from frontend
        # update observable without running into cycles (e.g. js updating obs
        # julia updating js, ...)
        Base.invokelatest(update_nocycle!, obs, data["payload"])
    elseif typ == JavascriptError
        @error "Error in Javascript: $(data["message"])\n with exception:\n$(data["exception"])"
    elseif typ == JavascriptWarning
        @warn "Error in Javascript: $(data["message"])\n)"
    else
        @error "Unrecognized message: $(typ) with type: $(typeof(type))"
    end
end

function wait_timeout(condition, error_msg, timeout = 5.0)
    start_time = time()
    while !condition()
        sleep(0.001)
        if (time() - start_time) > timeout
            error(error_msg)
        end
    end
    return true
end


"""
    handles a new websocket connection to a session
"""
function websocket_handler(
        application::Application, request::Request, websocket::WebSocket
    )
    sessionid = request_to_sessionid(request)
    # Look up the connection in our sessions
    if haskey(application.sessions, sessionid)
        session = application.sessions[sessionid]
        # Close already open connections
        # TODO, actually, if the connection is open, we should
        # just not allow a new connection!? Need to figure out if that would
        # be less reliable...Definitely sounds more secure to not allow a new conenction
        if isopen(session)
            close(session.connection[])
        end
        session.connection[] = websocket
        wait_timeout(()-> isopen(websocket), "Websocket not open after waiting 5.0")
        while isopen(websocket)
            try
                handle_ws_message(session, read(websocket))
            catch e
                if !(e isa WebSockets.WebSocketClosedError)
                    @warn "handle ws error" exception=e
                end
            end
        end
        close(session)
    else
        error("Unregistered session id: $sessionid")
    end
end
