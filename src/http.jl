# Save some bytes by using ints for switch variable
const UpdateObservable = "0"
const OnjsCallback = "1"
const EvalJavascript = "2"
const JavascriptError = "3"
const JavascriptWarning = "4"

const JSCall = "5"
const JSGetIndex = "6"
const JSSetIndex = "7"

"""
    request_to_sessionid(request; throw = true)

Returns the session and browser id from request.
With throw = false, it can be used to check if a request
contains a valid session/browser id for a websocket connection.
Will return nothing if request is invalid!
"""
function request_to_sessionid(request; throw = true)
    if length(request.target) >= 1 + 36 + 1 + 3 + 1 # for /36session_id/4browser_id/
        session_browser = split(request.target, "/", keepempty = false)
        if length(session_browser) == 2
            sessionid, browserid = string.(session_browser)
            if length(sessionid) == 36 && length(browserid) == 4
                return sessionid, browserid
            end
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
    serialize_string(io, JSCallLibLocal)
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

function file_server(context)
    path = context.request.target
    if haskey(AssetRegistry.registry, path)
        filepath = AssetRegistry.registry[path]
        if isfile(filepath)
            return HTTP.Response(
                200,
                [
                    "Access-Control-Allow-Origin" => "*",
                    "Content-Type" => file_mimetype(filepath)
                ],
                body = read(filepath)
            )
        end
    end
    return HTTP.Response(404)
end

function getsession(application, request)
    sessionid, browserid = request_to_sessionid(request)
    if haskey(application.sessions, sessionid)
        browser_sessions = application.sessions[sessionid]
        if haskey(browser_sessions, browserid)
            return browser_sessions[browserid], browserid
        else
            error("Browser id not found: $(browserid)")
        end
    else
        error("Session id not found: $(sessionid)")
    end
end

function html(body)
    HTTP.Response(
        200,
        ["Content-Type" => "text/html"],
        body = body
    )
end

function response_404(body = "Not Found")
    HTTP.Response(
        404,
        ["Content-Type" => "text/html"],
        body = body
    )
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
    return
end

function handle_ws_connection(session::Session, websocket::WebSocket)
    # TODO, do we actually need to wait here?!
    wait_timeout(()-> isopen(websocket), "Websocket not open after waiting 5s")
    while isopen(websocket)
        try
            handle_ws_message(session, read(websocket))
        catch e
            # IOErrors
            if !(e isa WebSockets.WebSocketClosedError || e isa Base.IOError)
                @warn "handle ws error" exception=e
            end
        end
    end
    close(session)
end


"""
    handles a new websocket connection to a session
"""
function websocket_handler(
        context, websocket::WebSocket
    )
    request = context.request; application = context.application
    sessionid_browserid = request_to_sessionid(request)
    if sessionid_browserid === nothing
        error("Not a valid websocket request")
    end
    sessionid, browserid = sessionid_browserid
    # Look up the connection in our sessions
    if haskey(application.sessions, sessionid)
        browser_sessions = application.sessions[sessionid]
        session = get!(browser_sessions, browserid) do
            # If we don't have a session for this browser/client yet
            # we make a new one!
            return browser_sessions["base"]
        end
        # We can have multiple sessions for a client
        push!(session, websocket)
        handle_ws_connection(session, websocket)
    else
        error("Unregistered session id: $sessionid")
    end
end
