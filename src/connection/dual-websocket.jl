using .HTTPServer: Server
using HTTP.WebSockets

mutable struct DualWebsocket <: AbstractWebsocketConnection
    server::Server
    session::Union{Nothing,Session}
    low_latency::WebSocketHandler
    large_data::WebSocketHandler
end

DualWebsocket(proxy_callback::Function) = DualWebsocket(get_server(proxy_callback))
DualWebsocket() = DualWebsocket(get_server())
function DualWebsocket(server::Server)
    return DualWebsocket(server, nothing, WebSocketHandler(), WebSocketHandler())
end

# Both legs must be open: a DualWebsocket is only usable while BOTH the
# low-latency and large-data sockets are alive. Checking only `low_latency`
# meant that if the large-data leg died alone, the session stayed "ready",
# `write_large` kept failing/queueing forever, and nothing triggered a
# reconnect or flush. Requiring both flips the session not-ready so the
# normal reconnect/queue-replay path runs.
Base.isopen(ws::DualWebsocket) = isopen(ws.low_latency) && isopen(ws.large_data)

# JSDoneLoading can arrive over the first socket before the second opens.
# Wait outside the session lock so its queued updates remain writable.
function init_session(session::Session{DualWebsocket})
    status = wait_for(; timeout = 30) do
        isclosed(session) && return :closed
        isopen(session.connection)
    end
    status === :success || return
    return invoke(init_session, Tuple{Session}, session)
end

function Base.write(ws::DualWebsocket, binary::AbstractVector{UInt8})
    write(ws.low_latency, binary)
end

function write_large(ws::DualWebsocket, binary)
    write(ws.large_data, binary)
end

function Base.close(ws::DualWebsocket)
    close(ws.low_latency)
    close(ws.large_data)
    if !isnothing(ws.session)
        session = ws.session
        delete_websocket_route!(ws.server, "/$(session.id)?low_latency")
        delete_websocket_route!(ws.server, "/$(session.id)?large_data")
    end
    return
end

websocket_handlers(connection::DualWebsocket) = (connection.low_latency, connection.large_data)
websocket_handler(connection::DualWebsocket, uri) =
    uri.query == "low_latency" ? connection.low_latency : connection.large_data

function setup_connection(session::Session, connection::DualWebsocket)
    connection.session = session
    server = connection.server
    add_cleanup_task!(server)
    HTTPServer.websocket_route!(server, "/$(session.id)?low_latency" => connection)
    HTTPServer.websocket_route!(server, "/$(session.id)?large_data" => connection)
    external_url = HTTPServer.relative_url(server, "")
    return setup_websocket_connection_js(external_url, session;
        queries = ["?low_latency", "?large_data"])
end

function setup_connection(session::Session{DualWebsocket})
    return setup_connection(session, session.connection)
end
