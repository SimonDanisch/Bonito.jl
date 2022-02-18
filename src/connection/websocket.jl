using HTTP.WebSockets: WebSocket


mutable struct WebSocketConnection <: FrontendConnection
    socket::Union{Nothing, WebSocket}
end

function save_read(websocket)
    try
        # readavailable is what HTTP overloaded for websockets
        return readavailable(websocket)
    catch e
        if e isa HTTP.WebSockets.WebSocketError && e.status in (1001, 1000)
            # browser closed window / reload
            # which is an expected error
            @info("WS connection closed normally")
            return nothing
        elseif e isa Base.IOError
            @warn("WS connection closed because of IO error")
            return nothing
        else
            rethrow(e)
        end
    end
end

function Base.close(ws::WebSocketConnection)
    try
        # https://github.com/JuliaWeb/HTTP.jl/issues/649
        isopen(ws.socket) && close(ws.socket)
    catch e
        if !(e isa Base.IOError)
            @warn "error while closing websocket!" exception=e
        end
    end
end

function send_to_julia(session::Session{WebSocketConnection}, message::Dict{Symbol, Any})
    write(session.socket, serialize_binary(session, message))
end

function handle_ws_error(e)
    if !(e isa WebSockets.WebSocketClosedError || e isa Base.IOError)
        @warn "error in websocket handler!"
        Base.showerror(stderr, e, Base.catch_backtrace())
    end
end

function handle_ws_connection(server::Server, session::Session, websocket::WebSocket)
    try
        @debug("opening ws connection for session: $(session.id)")
        while !eof(websocket)
            bytes = save_read(websocket)
            # nothing means the browser closed the connection so we're done
            isnothing(bytes) && break
            try
                process_message(session, bytes)
            catch e
                # Only print any internal error to not close the connection
                Base.showerror(stderr, e, Base.catch_backtrace())
            end
        end
    finally
        # This always needs to happen, which is why we need a try catch!
        @debug("Closing: $(session.id)")
        close(session)
        delete!(server.sessions, session.id)
    end
end

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

"""
    handles a new websocket connection to a session
"""
function websocket_handler(context, websocket::WebSocket)
    request = context.request; application = context.application
    sessionid = request_to_sessionid(request, throw=true)
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

function init_connection(session::Session{WebSocketConnection})
    websocket_url
    return js"""
        $(JSServeLib).setup_connection({$(websocket_url), $(session.id)})
    """
end
