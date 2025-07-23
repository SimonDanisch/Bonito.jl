using HTTP.WebSockets: WebSocket, WebSocketError
using HTTP.WebSockets: receive, isclosed
using HTTP.WebSockets

mutable struct WebSocketHandler
    socket::Union{Nothing,WebSocket}
    lock::ReentrantLock
end

WebSocketHandler(socket) = WebSocketHandler(socket, ReentrantLock())
WebSocketHandler() = WebSocketHandler(nothing, ReentrantLock())

function safe_read(websocket)
    try
        # readavailable is what HTTP overloaded for websockets
        return receive(websocket)
    catch e
        if WebSockets.isok(e)
            # it's ok :shrug:
        elseif e isa Union{Base.IOError, EOFError}
            @debug("WS connection closed because of IO error")
            return nothing
        else
            rethrow(e)
        end
    end
end

function safe_write(websocket, binary)
    try
        # send is what HTTP overloaded for writing to a websocket
        send(websocket, binary)
        return true
    catch e
        if WebSockets.isok(e) || e isa Union{Base.IOError,EOFError}
            @warn "sending message to a closed websocket" maxlog = 1
            # it's ok :shrug:
            return nothing
        else
            rethrow(e)
        end
    end
end

function Base.isopen(ws::WebSocketHandler)
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

function Base.write(ws::WebSocketHandler, message::SerializedMessage)
    if isnothing(ws.socket)
        error("socket closed or not opened yet")
    end
    lock(ws.lock) do
        binary = serialize_binary(message)
        written = safe_write(ws.socket, binary)
        if written != true
            @debug "couldnt write, closing ws"
            close(ws)
        end
    end
end

function Base.close(ws::WebSocketHandler)
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

"""
    runs the main connection loop for the websocket
"""
function run_connection_loop(session::Session, handler::WebSocketHandler, websocket::WebSocket)
    @debug("opening ws connection for session: $(session.id)")
    handler.socket = websocket
    if session.status == SOFT_CLOSED
        session.status = OPEN
    end
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
