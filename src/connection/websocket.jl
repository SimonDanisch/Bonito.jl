using HTTP.WebSockets: WebSocket
using .HTTPServer: Server

mutable struct WebSocketConnection <: FrontendConnection
    socket::Union{Nothing, WebSocket}
end

WebSocketConnection() = WebSocketConnection(nothing)

const MATCH_HEX = r"[\da-f]"
const MATCH_UUID4 = MATCH_HEX^8 * r"-" * (MATCH_HEX^4 * r"-")^3 * MATCH_HEX^12



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

Base.isopen(ws::WebSocketConnection) = !isnothing(ws.socket) && isopen(ws.socket)

function Base.close(ws::WebSocketConnection)
    isnothing(ws.socket) && return
    try
        # https://github.com/JuliaWeb/HTTP.jl/issues/649
        isopen(ws) && close(ws.socket)
        ws.socket = nothing
    catch e
        if !(e isa Base.IOError)
            @warn "error while closing websocket!" exception=e
        end
    end
end

function send_to_js(session::Session{WebSocketConnection}, message::Dict{Symbol, Any})
    write(session.socket, serialize_binary(session, message))
end

function handle_ws_error(e)
    if !(e isa WebSockets.WebSocketClosedError || e isa Base.IOError)
        @warn "error in websocket handler!"
        Base.showerror(stderr, e, Base.catch_backtrace())
    end
end

function run_connection_loop(server::Server, session::Session, websocket::WebSocket)
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
    end
end

"""
    handles a new websocket connection to a session
"""
function (connection::WebSocketConnection)(context, websocket::WebSocket)
    println("Got the WS")
    request = context.request; application = context.application
    uri = URIs.URI(request.target).path
    session_id = URIs.splitpath(uri)[1]
    println("WS session id: $(session_id)")
    session = look_up_session(session_id)
    # Look up the connection in our sessions
    if !(isnothing(session))
        if isopen(session)
            # Would be nice to not error here - but I think this should never
            # Happen, and if it happens, we need to debug it!
            error("Session already has connection")
        end
        connection.socket = websocket
        run_connection_loop(application, session, websocket)
    else
        # This happens when an old session trys to reconnect to a new app
        # We somehow need to figure out better, how to recognize this
        @debug("Unregistered session id: $session_id.")
    end
end

function setup_connect(session::Session{WebSocketConnection})
    register_session(session)
    connection = session.connection
    server = HTTPServer.get_server()
    HTTPServer.websocket_route!(server, r"/" * MATCH_UUID4 => connection)
    proxy_url = "http://127.0.0.1:$(server.port)"
    return js"""
        (async () => {
            const Websocket = await $(Websocket)
            Websocket.setup_connection({proxy_url: $(proxy_url), session_id: $(session.id)})
        })()
    """
end
