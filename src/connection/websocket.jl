using .HTTPServer: Server
using HTTP.WebSockets

mutable struct WebSocketConnection <: FrontendConnection
    server::Server
    session::Union{Nothing,Session}
    low_latency::WebSocketHandler
    large_data::WebSocketHandler
end

WebSocketConnection(proxy_callback::Function) = WebSocketConnection(get_server(proxy_callback))
WebSocketConnection() = WebSocketConnection(get_server())
function WebSocketConnection(server::Server)
    return WebSocketConnection(server, nothing, WebSocketHandler(), WebSocketHandler())
end

Base.isopen(ws::WebSocketConnection) = isopen(ws.low_latency)

function Base.write(ws::WebSocketConnection, binary)
    write(ws.low_latency, binary)
end

function Base.close(ws::WebSocketConnection)
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
function (connection::WebSocketConnection)(context, websocket::WebSocket)
    request = context.request
    uri = URIs.URI(request.target)
    session_id = URIs.splitpath(uri.path)[1]
    @debug("WS session id: $(session_id)")
    session = connection.session
    if isnothing(session)
        error("Websocket connection skipped setup")
    end
    @assert session_id == session.id
    @show uri.query
    handler = uri.query == "low_latency" ? connection.low_latency : connection.large_data
    try
        run_connection_loop(session, handler, websocket)
    finally
        # This always needs to happen, which is why we need a try catch!
        if allow_soft_close(CLEANUP_POLICY[])
            @debug("Soft closing: $(session.id)")
            soft_close(session)
        else
            @debug("Closing: $(session.id)")
            # might as well close it immediately
            close(session)
        end
    end
end


const SERVER_CLEANUP_TASKS = Dict{Server, Tuple{Task, Base.RefValue{Bool}}}()

"""
    abstract type CleanupPolicy end

You can create a custom cleanup policy by subclassing this type. Implementing
the `should_cleanup` and `allow_soft_close` methods is required. You can also
implement `set_cleanup_time!`if it makes sense for your policy.

    function should_cleanup(policy::MyCleanupPolicy, session::Session)

    function allow_soft_close(policy::MyCleanupPolicy)

    function set_cleanup_time!(policy::MyCleanupPolicy, time_in_hrs::Real)

This is quite low level, and you implementaiton should probably start by copying `DefaultCleanupPolicy`.
"""
abstract type CleanupPolicy end

"""
    mutable struct DefaultCleanupPolicy <: CleanupPolicy
        session_open_wait_time=30
        cleanup_time=0.0
    end

This is the default cleanup policy. It closes sessions after
`session_open_wait_time` seconds (default 30) if the browser didn't connect
back to the displayed session. It also closes sessions after `cleanup_time`
hours (default 0) if the session closes cleanly, indicating that the
browser may reconnect if a tab is later restored. It returns true for
allow_soft_close(...) when `cleanup_time` is non-zero.
"""
mutable struct DefaultCleanupPolicy <: CleanupPolicy
    session_open_wait_time::Real
    cleanup_time::Real
end

DefaultCleanupPolicy() = DefaultCleanupPolicy(30, 0.0)

"""
    set_cleanup_time!(time_in_hrs::Real)

Sets the time that sessions remain open after the browser tab is closed.
This allows reconnecting to the same session.
Only works for Websocket connection inside VSCode right now,
and will display the same App again from first display.
State that isn't stored in Observables inside that app is lost.
"""
function set_cleanup_time!(time_in_hrs::Real)
    set_cleanup_time!(CLEANUP_POLICY[], time_in_hrs)
end

function set_cleanup_time!(policy::DefaultCleanupPolicy, time_in_hrs::Real)
    policy.cleanup_time = time_in_hrs
end

"""
    set_cleanup_policy!(policy::CleanupPolicy)

You can set a custom cleanup policy by calling this function.
"""
function set_cleanup_policy!(policy::CleanupPolicy)
    CLEANUP_POLICY[] = policy
end

const CLEANUP_POLICY = Ref{CleanupPolicy}(DefaultCleanupPolicy())

function should_cleanup(policy::DefaultCleanupPolicy, session::Session)
    if session.status == SOFT_CLOSED
        age = time() - session.closing_time
        age_hours = age / 60 / 60
        if age_hours > policy.cleanup_time
            return true
        end
    elseif !isopen(session) && session.status == DISPLAYED
        # if the session is not SOFT_CLOSED,
        # closing time means time at which rendering was done and the html was send to the browser
        rendered_time_point = session.closing_time
        # If the browser didn't connect back to the displayed session after 30s
        # we assume displaying didn't work for whatever reason and close it.
        if time() - rendered_time_point > policy.session_open_wait_time
            return true
        end
    end
    return false
end

function allow_soft_close(policy::DefaultCleanupPolicy=CLEANUP_POLICY[])
    return policy.cleanup_time > 0.0
end

function cleanup_server(server::Server)
    remove = Set{WebSocketConnection}()
    lock(server.websocket_routes.lock) do
        for (route, connection) in server.websocket_routes.table
            if connection isa WebSocketConnection
                session = connection.session
                if isnothing(session) || should_cleanup(CLEANUP_POLICY[], session)
                    push!(remove, connection)
                end
            end
        end
        for connection in remove
            if !isnothing(connection.session)
                session = connection.session
                close(session)
            end
        end
    end
end

function add_cleanup_task!(server::Server)
    get!(SERVER_CLEANUP_TASKS, server) do
        close_ref = Base.RefValue(true)
        task = @async while close_ref[]
            try
                sleep(1)
                cleanup_server(server)
            catch e
                if !(e isa EOFError)
                    @warn "error while cleaning up server" exception=(e, Base.catch_backtrace())
                end
            end
        end
        return (task, close_ref)
    end
end

function setup_connection(session::Session, connection::WebSocketConnection)
    connection.session = session
    server = connection.server
    add_cleanup_task!(server)
    HTTPServer.websocket_route!(server, "/$(session.id)?low_latency" => connection)
    HTTPServer.websocket_route!(server, "/$(session.id)?large_data" => connection)
    external_url = online_url(server, "")
    return setup_websocket_connection_js(external_url, session)
end

function setup_connection(session::Session{WebSocketConnection})
    return setup_connection(session, session.connection)
end
