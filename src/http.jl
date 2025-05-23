# Save some bytes by using ints for switch variable
const UpdateObservable = "0"
const OnjsCallback = "1"
const EvalJavascript = "2"
const JavascriptError = "3"
const JavascriptWarning = "4"
const RegisterObservable = "5"
const JSDoneLoading = "8"
const FusedMessage = "9"

"""
    request_to_sessionid(request; throw = true)

Returns the session and browser id from request.
With throw = false, it can be used to check if a request
contains a valid session/browser id for a websocket connection.
Will return nothing if request is invalid!
"""
function request_to_sessionid(request; throw=true)
    if length(request.target) >= 42 # for /36session_id/4browser_id/
        session_browser = split(request.target, "/", keepempty=false)
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

function html(body)
    return HTTP.Response(200, ["Content-Type" => "text/html", "charset" => "utf-8"], body=body)
end

function response_404(body="Not Found")
    return HTTP.Response(404, ["Content-Type" => "text/html", "charset" => "utf-8"], body=body)
end

function replace_url(match_str)
    key_regex = r"(/assetserver/[a-z0-9]+-.*?):([\d]+):[\d]+"
    m = match(key_regex, match_str)
    key = m[1]
    path = assetserver_to_localfile(string(key))
    return path * ":" * m[2]
end

const ASSET_URL_REGEX = r"http://.*/assetserver/([a-z0-9]+-.*?):([\d]+):[\d]+"

"""
    handle_ws_message(session::Session, message)

Handles the incoming websocket messages from the frontend
"""
function handle_ws_message(session::Session, message)
    isempty(message) && return
    data = MsgPack.unpack(message)
    typ = data["msg_type"]
    if typ == UpdateObservable
        registered, obs = session.observables[data["id"]]
        Base.invokelatest(update_nocycle!, obs, data["payload"])
    elseif typ == JavascriptError
        show(stderr, JSException(data))
    elseif typ == JavascriptWarning
        @warn "Error in Javascript: $(data["message"])\n)"
    elseif typ == JSDoneLoading
        if data["exception"] !== "null"
            exception = JSException(data)
            show(stderr, exception)
            session.init_error[] = exception
        end
        session.on_websocket_ready(session)
    else
        @error "Unrecognized message: $(typ) with type: $(typeof(type))"
    end
end

function handle_ws_error(e)
    if !(e isa WebSockets.WebSocketClosedError || e isa Base.IOError)
        @warn "error in websocket handler!"
        Base.showerror(stderr, e, Base.catch_backtrace())
    end
end

function handle_ws_connection(application::Server, session::Session, websocket::WebSocket)
    # We need two tries here
    # First, isopen may throw -.-...
    # Second, we need the finally to guruantee to delete + close the session
    # The inner try is of course to not break the loop on error
    try
        @debug("opening ws connection for session: $(session.id)")
        while isopen(websocket)
            try
                bytes = read(websocket)
                handle_ws_message(session, bytes)
            catch e
                handle_ws_error(e)
            end
        end
    catch e
        handle_ws_error(e)
    finally
        # This always needs to happen, which is why we need a try catch!
        @debug("Closing: $(session.id)")
        close(session)
        delete!(application.sessions, session.id)
    end
end

"""
    handles a new websocket connection to a session
"""
function websocket_handler(context, websocket::WebSocket)
    request = context.request; application = context.application
    sessionid_browserid = request_to_sessionid(request, throw=true)
    sessionid, browserid = sessionid_browserid
    # Look up the connection in our sessions
    if haskey(application.sessions, sessionid)
        session = application.sessions[sessionid]
        if isopen(session)
            # Would be nice to not error here - but I think this should never
            # Happen, and if it happens, we need to debug it!
            error("Session already has connection")
        end
        session.connection[] = websocket
        handle_ws_connection(application, session, websocket)
    else
        # This happens when an old session trys to reconnect to a new app
        # We somehow need to figure out better, how to recognize this
        @debug("Unregistered session id: $sessionid. Sessions: $(collect(keys(application.sessions)))")
    end
end
