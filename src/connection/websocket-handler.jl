using HTTP.WebSockets: WebSocket, WebSocketError
using HTTP.WebSockets: receive, isclosed
using HTTP.WebSockets

mutable struct WebSocketHandler
    socket::Union{Nothing,WebSocket}
    lock::ReentrantLock
    queue::Channel{SerializedMessage}
end

WebSocketHandler(socket) = WebSocketHandler(socket, ReentrantLock(), Channel{SerializedMessage}(0))
WebSocketHandler() = WebSocketHandler(nothing, ReentrantLock(), Channel{SerializedMessage}(0))

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
        # send is what HTTP overloaded for writing to a websocket
        send(websocket, binary)
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
            @debug "couldnt write, closing ws"
            close(ws)
        end
    end
end

function Base.write(ws::WebSocketHandler, message::SerializedMessage)
    put!(ws.queue, message)
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
    runs the main connection loop for the websocket
"""
function run_connection_loop(session::Session, handler::WebSocketHandler, websocket::WebSocket)
    @debug("opening ws connection for session: $(session.id)")
    handler.socket = websocket
    if session.status == SOFT_CLOSED
        session.status = OPEN
    end
    task = Threads.@spawn for msg in handler.queue
        isopen(handler) || break
        lock(handler.lock) do
            # write the message to the websocket
            _write(handler, msg)
        end
    end
    Base.errormonitor(task)
    while isopen(handler)
        bytes = safe_read(websocket)
        # nothing means the browser closed the connection so we're done
        isnothing(bytes) && break
        put!(session.inbox, bytes)
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
