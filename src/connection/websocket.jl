using .HTTPServer: Server
using HTTP.WebSockets

mutable struct WebSocketConnection <: FrontendConnection
    server::Server
    session::Union{Nothing,Session}
    handler::WebSocketHandler
end

WebSocketConnection(proxy_callback::Function) = WebSocketConnection(get_server(proxy_callback))
WebSocketConnection() = WebSocketConnection(get_server())
WebSocketConnection(server::Server) = WebSocketConnection(server, nothing, WebSocketHandler())

Base.isopen(ws::WebSocketConnection) = isopen(ws.handler)
Base.write(ws::WebSocketConnection, binary) = write(ws.handler, binary)
Base.close(ws::WebSocketConnection) = close(ws.handler)

function run_connection_loop(server::Server, session::Session, connection::WebSocketConnection, websocket::WebSocket)
    # the channel is used so that we can do async processing of messages
    # While still keeping the order of messages
    try
        run_connection_loop(session, connection.handler, websocket)
    finally
        # This always needs to happen, which is why we need a try catch!
        if CLEANUP_TIME[] == 0.0
            @debug("Closing: $(session.id)")
            # might as well close it immediately
            close(session)
            delete_websocket_route!(server, "/$(session.id)")
        else
            @debug("Soft closing: $(session.id)")
            soft_close(session)
        end
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
    run_connection_loop(application, session, connection, websocket)
end


const SERVER_CLEANUP_TASKS = Dict{Server, Task}()

const CLEANUP_TIME = Ref(0.0)

"""
    set_cleanup_time!(time_in_hrs::Real)

Sets the time that sessions remain open after the browser tab is closed.
This allows reconnecting to the same session.
Only works for Websocket connection inside VSCode right now,
and will display the same App again from first display.
State that isn't stored in Observables inside that app is lost.
"""
function set_cleanup_time!(time_in_hrs::Real)
    CLEANUP_TIME[] = time_in_hrs
end

const SESSION_OPEN_WAIT_TIME = Ref(30)

function cleanup_server(server::Server)
    remove = Set{WebSocketConnection}()
    lock(server.websocket_routes.lock) do
        for (route, connection) in server.websocket_routes.table
            if connection isa WebSocketConnection
                session = connection.session
                if isnothing(session)
                    push!(remove, connection)
                elseif session.status == SOFT_CLOSED
                    age = time() - session.closing_time
                    age_hours = age / 60 / 60
                    if age_hours > CLEANUP_TIME[]
                        push!(remove, connection)
                    end
                elseif !isopen(session) && session.status == DISPLAYED
                    # if the session is not SOFT_CLOSED,
                    # closing time means time at which rendering was done and the html was send to the browser
                    rendered_time_point = session.closing_time
                    # If the browser didn't connect back to the displayed session after 30s
                    # we assume displaying didn't work for whatever reason and close it.
                    if time() - rendered_time_point > SESSION_OPEN_WAIT_TIME[]
                        push!(remove, connection)
                    end
                end
            end
        end
        for connection in remove
            if !isnothing(connection.session)
                session = connection.session
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
                if !(e isa EOFError)
                    @warn "error while cleaning up server" exception=(e, Base.catch_backtrace())
                end
            end
        end
    end
end

function setup_connection(session::Session, connection::WebSocketConnection)
    connection.session = session
    server = connection.server
    add_cleanup_task!(server)
    HTTPServer.websocket_route!(server, "/$(session.id)" => connection)
    external_url = online_url(server, "")
    return setup_websocket_connection_js(external_url, session)
end

function setup_connection(session::Session{WebSocketConnection})
    return setup_connection(session, session.connection)
end
