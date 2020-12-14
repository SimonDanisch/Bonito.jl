# Save some bytes by using ints for switch variable
const UpdateObservable = "0"
const OnjsCallback = "1"
const EvalJavascript = "2"
const JavascriptError = "3"
const JavascriptWarning = "4"

const JSCall = "5"
const JSGetIndex = "6"
const JSSetIndex = "7"
const JSDoneLoading = "8"
const FusedMessage = "9"
const DeleteObjects = "10"
const OnUpdateObservable = "11"

"""
    request_to_sessionid(request; throw = true)

Returns the session and browser id from request.
With throw = false, it can be used to check if a request
contains a valid session/browser id for a websocket connection.
Will return nothing if request is invalid!
"""
function request_to_sessionid(request; throw=true)
    if length(request.target) >= 1 + 36 + 1 + 3 + 1 # for /36session_id/4browser_id/
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
        @assert registered # must have been registered to come from frontend
        # update observable without running into cycles (e.g. js updating obs
        # julia updating js, ...)
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

"""
    wait_timeout(condition, error_msg, timeout = 5.0)
Wait until `condition` function returns true. If running out of time throws `error_msg`!
"""
function wait_timeout(condition::Function, error_msg::String, timeout=5.0)
    start_time = time()
    while !condition()
        sleep(0.001)
        if (time() - start_time) > timeout
            error(error_msg)
        end
    end
    return
end

function handle_ws_connection(application::Application, session::Session, websocket::WebSocket)
    while !eof(websocket)
        try
            # TODO fuse all julia->js events triggered by an incoming message?
            handle_ws_message(session, readavailable(websocket))
        catch e
            # IOErrors
            ws_closed = (e isa HTTP.WebSockets.WebSocketError && e.status in (1001, 1000)) || e isa Base.IOError
            if !ws_closed
                err = CapturedException(e, Base.catch_backtrace())
                @warn "error in websocket handler!" exception=err
            end
        end
    end
    close(session)
    delete!(application.sessions, session.id)
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
        # We can have multiple sessions for a client
        push!(session, websocket)
        handle_ws_connection(application, session, websocket)
    else
        # This happens when an old session trys to reconnect to a new app
        # We somehow need to figure out better, how to recognize this
        @debug("Unregistered session id: $sessionid. Sessions: $(collect(keys(application.sessions)))")
    end
end
