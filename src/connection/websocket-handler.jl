using HTTP.WebSockets: WebSocket, WebSocketError
using HTTP.WebSockets: receive, isclosed
using HTTP.WebSockets

mutable struct WebSocketHandler
    @atomic socket::Union{Nothing,WebSocket}
    lock::ReentrantLock
end

WebSocketHandler(socket) = WebSocketHandler(socket, ReentrantLock())
WebSocketHandler() = WebSocketHandler(nothing, ReentrantLock())

function ws_should_throw(e)
    # any close, 1006 (peer vanished) included, just ends the connection
    e isa WebSocketError && return false
    e isa Union{Base.IOError,EOFError} && return false
    e isa ArgumentError && e.msg == "send() requires `!(ws.writeclosed)`" && return false
    return true
end

function safe_read(websocket)
    try
        # readavailable is what HTTP overloaded for websockets
        return receive(websocket)
    catch e
        # closing a replaced socket (`install_socket!`) closes the channel we wait on
        e isa InvalidStateException && !isopen(websocket.readchannel) && return nothing
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

# No lock: a write blocked on a peer that stopped reading holds it, and the
# cleanup task calls this holding the route table, stalling every upgrade.
function Base.isopen(ws::WebSocketHandler)
    socket = @atomic ws.socket
    isnothing(socket) && return false
    # isclosed(socket) returns readclosed && writeclosed
    # but we consider it closed if either is closed?
    if socket.readclosed || socket.writeclosed
        return false
    end
    # So, it turns out, ws connection where the tab gets closed
    # stay open indefinitely, but aren't writable anymore
    # TODO, figure out how to check for that
    return true
end

function Base.write(ws::WebSocketHandler, binary::AbstractVector{UInt8})
    lock(ws.lock) do
        socket = @atomic ws.socket
        if isnothing(socket)
            error("socket closed or not opened yet")
        end
        written = safe_write(socket, binary)
        if written != true
            # The connection is gone: end the transport (a polite close waits
            # for the peer) and THROW so `_send` queues the message for replay.
            @debug "couldnt write, closing ws"
            @atomic ws.socket = nothing
            socket.close_transport!()
            error("websocket write failed; socket closed")
        end
    end
end

function Base.close(ws::WebSocketHandler)
    lock_unwedged(ws) do
        socket = @atomic ws.socket
        isnothing(socket) && return
        try
            @atomic ws.socket = nothing
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
socket) does NOT tear down the session now owned by the new socket.
"""
function is_current_socket(handler::WebSocketHandler, websocket::WebSocket)
    lock(handler.lock) do
        return (@atomic handler.socket) === websocket
    end
end

# Runs `f` holding the handler lock. A write to a peer that stopped reading (a
# frozen phone tab) holds it until TCP gives up; after `grace` seconds we end
# that socket's transport, so the write fails and its message is queued for replay.
function lock_unwedged(f, handler::WebSocketHandler; grace = 2.0)
    deadline = time() + grace
    acquired = trylock(handler.lock)
    while !acquired && time() < deadline
        sleep(0.05)
        acquired = trylock(handler.lock)
    end
    if !acquired
        wedged = @atomic handler.socket
        isnothing(wedged) || wedged.close_transport!()
        lock(handler.lock)
    end
    try
        return f()
    finally
        unlock(handler.lock)
    end
end

# The page dialed a new socket, so the old one is dead to it: don't wait on a
# write wedged there, and close it (a silent one would linger forever). 4409
# only reaches a page still listening, i.e. a duplicated tab, and tells it not
# to reconnect, so two tabs don't keep taking the session from each other.
function install_socket!(handler::WebSocketHandler, websocket::WebSocket)
    previous = lock_unwedged(handler) do
        old = @atomic handler.socket
        @atomic handler.socket = websocket
        return old
    end
    isnothing(previous) || errormonitor(@async close(previous, WebSockets.CloseFrameBody(4409, "replaced")))
    return
end

"""
    runs the main connection loop for the websocket
"""
function run_connection_loop(session::Session, handler::WebSocketHandler, websocket::WebSocket)
    @debug("opening ws connection for session: $(session.id)")
    install_socket!(handler, websocket)
    if session.status == SOFT_CLOSED
        session.status = OPEN
    end
    while isopen(handler)
        bytes = safe_read(websocket)
        # nothing means the browser closed the connection so we're done
        isnothing(bytes) && break
        # `isopen(inbox) || break` then `put!` is a check-then-act race:
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
