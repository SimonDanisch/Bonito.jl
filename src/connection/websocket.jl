using HTTP.WebSockets: WebSocket, WebSocketError
using .HTTPServer: Server
using HTTP.WebSockets: receive, isclosed
using HTTP.WebSockets

mutable struct WebSocketConnection <: FrontendConnection
    server::Server
    socket::Union{Nothing,WebSocket}
    lock::ReentrantLock
    session::Union{Nothing,Session}
end

WebSocketConnection(proxy_callback::Function) = WebSocketConnection(get_server(proxy_callback))
WebSocketConnection() = WebSocketConnection(get_server())
WebSocketConnection(server::Server) = WebSocketConnection(server, nothing, ReentrantLock(), nothing)

function save_read(websocket)
    try
        # readavailable is what HTTP overloaded for websockets
        return receive(websocket)
    catch e
        if WebSockets.isok(e)
            # it's ok :shrug:
        elseif e isa Union{Base.IOError, EOFError}
            @info("WS connection closed because of IO error")
            return nothing
        else
            rethrow(e)
        end
    end
end

function save_write(websocket, binary)
    try
        # send is what HTTP overloaded for writing to a websocket
        send(websocket, binary)
        return true
    catch e
        @warn "sending message to a closed websocket" maxlog = 1
        if WebSockets.isok(e) || e isa Union{Base.IOError,EOFError}
            # it's ok :shrug:
            return nothing
        else
            rethrow(e)
        end
    end
end

function Base.isopen(ws::WebSocketConnection)
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

function Base.write(ws::WebSocketConnection, binary)
    if isnothing(ws.socket)
        error("socket closed or not opened yet")
    end
    lock(ws.lock) do
        written = save_write(ws.socket, binary)
        if written != true
            @debug "couldnt write, closing ws"
            close(ws)
        end
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

function run_connection_loop(server::Server, session::Session, connection::WebSocketConnection)
    try
        @debug("opening ws connection for session: $(session.id)")
        websocket = connection.socket
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
        soft_close(session)
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
    status = session.status
    connection.socket = websocket
    if status == SOFT_CLOSED && !isnothing(session.current_app[])
        update_app!(session, session.current_app[])
    end
    run_connection_loop(application, session, connection)
end


const SERVER_CLEANUP_TASKS = Dict{Server, Task}()

const CLEANUP_TIME = Ref(0.0)

function set_cleanup_time!(time)
    CLEANUP_TIME[] = time
end

function cleanup_server(server::Server)
    remove = Set{WebSocketConnection}()
    lock(server.websocket_routes.lock) do
        for (route, handler) in server.websocket_routes.table
            if handler isa WebSocketConnection
                session = handler.session
                if isnothing(session)
                    push!(remove, handler)
                elseif session.status == SOFT_CLOSED
                    age = time() - session.closing_time
                    age_hours = age / 60 / 60
                    if age_hours > CLEANUP_TIME[]
                        push!(remove, handler)
                    end
                elseif session.status == CLOSED
                    push!(remove, handler)
                end
            end
        end
        for handler in remove
            if !isnothing(handler.session)
                session = handler.session
                delete_websocket_route!(server, "/$(session.id)")
                close(session)
            end
        end
    end
end


function add_cleanup_task!(server::Server)
    get!(SERVER_CLEANUP_TASKS, server) do
        @async while true
            try
                sleep(1)
                cleanup_server(server)
            catch e
                @warn "error while cleaning up server" exception=(e, Base.catch_backtrace())
            end
        end
    end
end

function setup_connection(session::Session, connection::WebSocketConnection)
    connection.session = session
    server = connection.server
    add_cleanup_task!(server)
    HTTPServer.websocket_route!(server, "/$(session.id)" => connection)
    proxy_url = online_url(server, "")
    return js"""
        $(Websocket).then(WS => {
            WS.setup_connection({proxy_url: $(proxy_url), session_id: $(session.id), compression_enabled: $(session.compression_enabled)})
        })
    """
end

function setup_connection(session::Session{WebSocketConnection})
    return setup_connection(session, session.connection)
end
