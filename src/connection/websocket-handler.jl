using HTTP.WebSockets: WebSocket, WebSocketError
using HTTP.WebSockets: receive, isclosed
using HTTP.WebSockets

mutable struct WebSocketHandler
    socket::Union{Nothing,WebSocket}
    lock::ReentrantLock
end

WebSocketHandler(socket) = WebSocketHandler(socket, ReentrantLock())
WebSocketHandler() = WebSocketHandler(nothing, ReentrantLock())

function ws_should_throw(e)
    WebSockets.isok(e) && return false
    e isa Union{Base.IOError,EOFError} && return false
    e isa ArgumentError && e.msg == "send() requires `!(ws.writeclosed)`" && return false
    return true
end

function safe_read(websocket)
    try
        # readavailable is what HTTP overloaded for websockets
        return receive(websocket)
    catch e
        ws_should_throw(e) && rethrow(e)
        return nothing
    end
end


function safe_write(websocket, binary)
    try
        # `send` writes a frame to the websocket. HTTP.jl 2.0 no longer exports
        # it from `HTTP.WebSockets`, so it must be qualified — an unqualified
        # `send` would resolve to Bonito's own `send(::Session, …)` and throw a
        # MethodError that gets swallowed into the message queue.
        WebSockets.send(websocket, binary)
        return true
    catch e
        ws_should_throw(e) && rethrow(e)
        return nothing
    end
end

function Base.isopen(ws::WebSocketHandler)
    lock(ws.lock) do
        isnothing(ws.socket) && return false
        # isclosed(ws.socket) returns readclosed && writeclosed
        # but we consider it closed if either is closed?
        if ws.socket.readclosed || ws.socket.writeclosed
            return false
        end
        # So, it turns out, ws connection where the tab gets closed
        # stay open indefinitely, but aren't writable anymore
        # TODO, figure out how to check for that
        return true
    end
end

function Base.write(ws::WebSocketHandler, binary::AbstractVector{UInt8})
    lock(ws.lock) do
        if isnothing(ws.socket)
            error("socket closed or not opened yet")
        end
        written = safe_write(ws.socket, binary)
        if written != true
            # The send failed (dying socket). Close our side, then THROW so
            # `_send` falls into its queue-for-replay branch (B2). Returning
            # normally here used to silently drop the first message into a
            # dead socket — not on the wire, not queued. The `close(ws)` runs
            # first so the handler is torn down before we signal failure.
            @debug "couldnt write, closing ws"
            close(ws)
            error("websocket write failed; socket closed")
        end
    end
end

function Base.close(ws::WebSocketHandler)
    lock(ws.lock) do
        isnothing(ws.socket) && return
        try
            socket = ws.socket
            ws.socket = nothing
            isclosed(socket) || close(socket)
        catch e
            ws_should_throw(e) && @warn "error while closing websocket" exception=e
        end
    end
end

"""
    is_current_socket(handler, websocket) -> Bool

True iff `websocket` is still the socket `handler` is bound to. Used by the WS
connection callback's `finally` so a *stale* loop (an old, half-open socket
still parked in `safe_read` when the browser reconnected and installed a new
socket) does NOT tear down the session now owned by the new socket (B3).
"""
function is_current_socket(handler::WebSocketHandler, websocket::WebSocket)
    lock(handler.lock) do
        return handler.socket === websocket
    end
end

"""
    runs the main connection loop for the websocket
"""
function run_connection_loop(session::Session, handler::WebSocketHandler, websocket::WebSocket)
    @debug("opening ws connection for session: $(session.id)")
    # Install this socket as the handler's current socket under the lock so a
    # reconnect that swaps the socket is atomic w.r.t. `isopen`/`is_current_socket`.
    lock(handler.lock) do
        handler.socket = websocket
    end
    if session.status == SOFT_CLOSED
        session.status = OPEN
    end
    while isopen(handler)
        bytes = safe_read(websocket)
        # nothing means the browser closed the connection so we're done
        isnothing(bytes) && break
        # `isopen(inbox) || break` then `put!` is a check-then-act race (B23):
        # the channel can close in the gap (a concurrent `close(session)`),
        # and `put!` then throws InvalidStateException, which escapes the loop
        # and lets the `finally` soft_close an already-CLOSED session. Catch
        # exactly that closed-channel signal and break cleanly instead.
        isopen(session.inbox) || break
        try
            put!(session.inbox, bytes)
        catch e
            e isa InvalidStateException && break
            rethrow()
        end
    end
end


"""
    returns the javascript snippet to setup the connection
"""
function setup_websocket_connection_js(
    proxy_url, session::Session; query="", main_connection=true)
    return js"""
        $(Websocket).then(WS => {
            WS.setup_connection({
                proxy_url: $(proxy_url),
                session_id: $(session.id),
                compression_enabled: $(session.compression_enabled),
                query: $(query),
                main_connection: $(main_connection)
            })
        })
    """
end
