# Save some bytes by using ints for switch variable
const UpdateObservable = "0"
const OnjsCallback = "1"
const EvalJavascript = "2"
const JavascriptError = "3"
const JavascriptWarning = "4"

function stream_handler(application::Application, stream::Stream)
    try
        if WebSockets.is_upgrade(stream)
            WebSockets.upgrade(stream) do request, websocket
                websocket_handler(application, request, websocket)
            end
            return
        end
    catch err
        @error "error in upgrade" exception = err
    end
    try
        f = HTTP.RequestHandlerFunction() do request
            http_handler(application, request)
        end
        HTTP.handle(f, stream)
    catch err
        @error "error in handle http" exception = err
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
        <!doctype html>
        <html>
        <head>
        <meta charset="UTF-8">
        """
    )
    # Insert all script/css dependencies into the header
    tojsstring(io, session.dependencies)
    # insert the javascript for JSCall
    print(io, """
        <script>
            window.js_call_session_id = $(repr(sessionid))
        """)
    if !isempty(url_proxy[])
        print(io, """
            window.websocket_proxy_url = $(repr(url_proxy[]))
        """)
    end
    println(io, """
        function __on_document_load__(){
    """)
    # create a function we call in body onload =, which loads all
    # on_document_load javascript
    tojsstring(io, session.on_document_load)
    print(io, """
            }
        </script>
        """
    )
    tojsstring(io, JSCallLib)
    queued_as_script(io, session)
    print(io, """

        <meta name="viewport" content="width=device-width, initial-scale=1">
        </head>
        <body"""
    )

    if !isempty(session.on_document_load)
        # insert on document load javascript if we have any
        print(io, " onload = '__on_document_load__()'")
    end
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
            sessionid = string(uuid4())
            session = Session(Ref{WebSocket}())
            application.sessions[sessionid] = session
            dom = Base.invokelatest(application.dom, session, request)
            return HTTP.Response(
                200,
                ["Content-Type" => "text/html"],
                body = dom2html(session, sessionid, dom)
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
    if length(request.target) > 2 # for /id/
        sessionid = split(request.target, "/", keepempty = false)[end] # remove the '/' id '/'
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
            @warn "Unrecognized session id: $sessionid"
        end
    else
        @warn "Unrecognized Websocket route: $(request.target)"
    end
end
