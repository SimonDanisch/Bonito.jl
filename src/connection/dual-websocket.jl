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

"""
    handles a new websocket connection to a session
"""
function (connection::DualWebsocket)(context, websocket::WebSocket)
    request = context.request
    uri = URIs.URI(request.target)
    session_id = URIs.splitpath(uri.path)[1]
    @debug("WS session id: $(session_id)")
    session = connection.session
    if isnothing(session)
        error("Websocket connection skipped setup")
    end
    @assert session_id == session.id
    handler = uri.query == "low_latency" ? connection.low_latency : connection.large_data
    try
        run_connection_loop(session, handler, websocket)
    finally
        # Close our own handler only if this socket is still current; a stale
        # loop must not tear down the live socket a reconnect installed.
        if is_current_socket(handler, websocket)
            close(handler)
        else
            @debug("Stale ws loop for $(session.id) exiting; not closing handler")
        end
        # Fire the session transition once BOTH legs are dead, regardless of which
        # leg (stale or not) observes it last. Gating this on `is_current_socket`
        # let a stale last leg exit without firing it, leaking the session as OPEN.
        # Idempotent via the CLOSED guard. Require both legs dead so the first leg
        # to drop doesn't kill a session the other is still serving (e.g. JSDoneLoading).
        if !isopen(connection.low_latency) && !isopen(connection.large_data)
            if allow_soft_close(CLEANUP_POLICY[])
                @debug("Soft closing: $(session.id)")
                soft_close(session)
            else
                @debug("Closing: $(session.id)")
                close(session)
            end
        end
    end
end

function setup_connection(session::Session, connection::DualWebsocket)
    connection.session = session
    server = connection.server
    add_cleanup_task!(server)
    HTTPServer.websocket_route!(server, "/$(session.id)?low_latency" => connection)
    HTTPServer.websocket_route!(server, "/$(session.id)?large_data" => connection)
    external_url = HTTPServer.relative_url(server, "")
    js_ll = setup_websocket_connection_js(external_url, session; query="?low_latency")
    js_ld = setup_websocket_connection_js(external_url, session; query="?large_data", main_connection=false)
    return js"{
        $(js_ll)
        $(js_ld)
    }"
end

function setup_connection(session::Session{DualWebsocket})
    return setup_connection(session, session.connection)
end
