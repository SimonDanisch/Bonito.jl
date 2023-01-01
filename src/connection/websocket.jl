using HTTP.WebSockets: WebSocket, WebSocketError
using .HTTPServer: Server
using HTTP.WebSockets: receive, isclosed
using HTTP.WebSockets

mutable struct WebSocketConnection <: FrontendConnection
    server::Union{Nothing, Server}
    socket::Union{Nothing, WebSocket}
    lock::ReentrantLock
    session::Union{Nothing, Session}
end

WebSocketConnection() = WebSocketConnection(nothing, nothing, ReentrantLock(), nothing)
WebSocketConnection(server::Server) = WebSocketConnection(server, nothing, ReentrantLock(), nothing)

"""
    WebSocketConnection(proxy_url::Function)

Constructor for a websocket behind a proxy!
"""
function WebSocketConnection(proxy_url::Function)
    server = Server("0.0.0.0", 8083)
    real_port = server.port # can change if already in use
    server.proxy_url = proxy_url(real_port) # which is why the url needs to be a callbacks
    return WebSocketConnection(server)
end


const MATCH_HEX = r"[\da-f]"
const MATCH_UUID4 = MATCH_HEX^8 * r"-" * (MATCH_HEX^4 * r"-")^3 * MATCH_HEX^12

function save_read(websocket)
    try
        # readavailable is what HTTP overloaded for websockets
        return receive(websocket)
    catch e
        if WebSockets.isok(e)
            # it's ok :shrug:
        elseif e isa Union{Base.IOError, EOFError}
            @warn("WS connection closed because of IO error")
            return nothing
        else
            rethrow(e)
        end
    end
end

Base.isopen(ws::WebSocketConnection) = !isnothing(ws.socket) && !isclosed(ws.socket)

function Base.write(ws::WebSocketConnection, binary)
    lock(ws.lock) do
        send(ws.socket, binary)
    end
end

function Base.close(ws::WebSocketConnection)
    isnothing(ws.socket) && return
    try
        socket = ws.socket
        ws.socket = nothing
        isclosed(socket) || close(socket)
    catch e
        if !WebSockets.isok(e)
            @warn "error while closing websocket" exception=(e, Base.catch_backtrace())
        end
    end
end

function run_connection_loop(server::Server, session::Session, websocket::WebSocket)
    try
        @debug("opening ws connection for session: $(session.id)")
        while !isclosed(websocket)
            bytes = save_read(websocket)
            # nothing means the browser closed the connection so we're done
            isnothing(bytes) && break
            try
                process_message(session, bytes)
            catch e
                # Only print any internal error to not close the connection
                @warn "error while processing received msg" exception=(e, Base.catch_backtrace())
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
    request = context.request; application = context.application
    uri = URIs.URI(request.target).path
    session_id = URIs.splitpath(uri)[1]
    @debug("WS session id: $(session_id)")
    session = connection.session
    if isnothing(session)
        error("Websocket connection skipped setup")
    end
    @assert session_id == session.id
    # Look up the connection in our sessions
    if isopen(session)
        # Would be nice to not error here - but I think this should never
        # Happen, and if it happens, we need to debug it!
        error("Session already has connection")
    end
    connection.socket = websocket
    run_connection_loop(application, session, websocket)

end

function setup_connection(session::Session, connection::WebSocketConnection)
    if isnothing(connection.server)
        # Use our global singleton server
        connection.server = HTTPServer.get_server()
    end
    connection.session = session
    server = connection.server

    HTTPServer.websocket_route!(server, r"/" * MATCH_UUID4 => connection)

    proxy_url = online_url(server, "")
    return js"""
        $(Websocket).then(WS => {
            WS.setup_connection({proxy_url: $(proxy_url), session_id: $(session.id)})
        })
    """
end

function setup_connection(session::Session{WebSocketConnection})
    return setup_connection(session, session.connection)
end
