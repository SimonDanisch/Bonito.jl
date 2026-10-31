using .HTTPServer: Server
using HTTP.WebSockets

mutable struct WebSocketConnection <: AbstractWebsocketConnection
    server::Server
    session::Union{Nothing,Session}
    handler::WebSocketHandler
end

WebSocketConnection(proxy_callback::Function) = WebSocketConnection(get_server(proxy_callback))
WebSocketConnection() = WebSocketConnection(get_server())
function WebSocketConnection(server::Server)
    return WebSocketConnection(server, nothing, WebSocketHandler())
end

Base.isopen(ws::WebSocketConnection) = isopen(ws.handler)

function Base.write(ws::WebSocketConnection, binary::AbstractVector{UInt8})
    write(ws.handler, binary)
end

function Base.close(ws::WebSocketConnection)
    close(ws.handler)
    if !isnothing(ws.session)
        session = ws.session
        delete_websocket_route!(ws.server, "/$(session.id)")
        close(session)
    end
    return
end

websocket_handlers(connection::WebSocketConnection) = (connection.handler,)
websocket_handler(connection::WebSocketConnection, uri) = connection.handler

function (connection::AbstractWebsocketConnection)(context, websocket::WebSocket)
    uri = URIs.URI(context.request.target)
    session = connection.session
    isnothing(session) && error("Websocket connection skipped setup")
    @assert URIs.splitpath(uri.path)[1] == session.id
    handler = websocket_handler(connection, uri)
    try
        run_connection_loop(session, handler, websocket)
    finally
        websocket.close_transport!()
        # Recheck ownership under the session lock before changing session state.
        # Failed writes retain the socket's identity for this check.
        condition() = is_current_socket(handler, websocket) &&
            !any(isopen, websocket_handlers(connection))
        if allow_soft_close(CLEANUP_POLICY[])
            soft_close(session; condition)
        else
            close_root_session(session; condition)
        end
    end
end


const SERVER_CLEANUP_TASKS = Dict{Server, Tuple{Task, Timer}}()
# `get!`/`delete!` on SERVER_CLEANUP_TASKS run from render tasks (via
# `setup_connection` → `add_cleanup_task!`) and from `close(server)`. The Dict
# has no internal synchronization, so concurrent access races a rehash.
const SERVER_CLEANUP_LOCK = Base.ReentrantLock()

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

# 30 seconds as cleanup wait time
# Allowing to reconnect for 30s after any event killing the websocket connection
# Without closing the tab.
DefaultCleanupPolicy() = DefaultCleanupPolicy(30, 30 / 60 / 60)

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
    elseif session.status == DISPLAYED && !isopen(session)
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
    # Lock-order discipline: `close(session)` acquires `deletion_lock`,
    # whose body eventually calls `delete_websocket_route!` which takes
    # `server.websocket_routes.lock`. Holding `websocket_routes.lock`
    # *while* calling close therefore inverts the order any user-initiated
    # close uses (deletion_lock → routes_lock) — the two paths can
    # deadlock. Snapshot the to-close set under routes_lock, RELEASE it,
    # then close.
    remove = FrontendConnection[]
    lock(server.websocket_routes.lock) do
        for (route, connection) in server.websocket_routes.table
            if connection isa FrontendConnection
                session = connection.session
                if isnothing(session) || should_cleanup(CLEANUP_POLICY[], session)
                    push!(remove, connection)
                end
            end
        end
    end
    for connection in remove
        session = connection.session
        if !isnothing(session)
            try
                close(session)
            catch e
                @warn "cleanup_server: close(session) raised" exception=(e, Base.catch_backtrace())
            end
        end
    end
end

function add_cleanup_task!(server::Server)
    lock(SERVER_CLEANUP_LOCK) do
        get!(SERVER_CLEANUP_TASKS, server) do
            # Own the timer so shutdown can close it, instead of leaving a
            # sleep(1) armed when a precompile workload finishes (#430).
            timer = Timer(1; interval = 1)
            task = @async try
                while isopen(timer)
                    try
                        wait(timer)
                    catch e
                        e isa EOFError || rethrow()
                        break
                    end
                    isopen(timer) || break
                    try
                        cleanup_server(server)
                    catch e
                        @warn "error while cleaning up server" exception=(e, Base.catch_backtrace())
                    end
                end
            finally
                close(timer)
            end
            return (task, timer)
        end
    end
end

"""
    stop_cleanup_task!(server::Server)

Stop and forget `server`'s 1-Hz cleanup task. Without this, the task runs
forever and the `SERVER_CLEANUP_TASKS` entry keeps a strong ref chain
(Dict → Server → routes → sessions) alive, defeating GC for every server ever
created. `close(server)` should call this. Idempotent / safe to call on a
server that never had a cleanup task.
"""
function stop_cleanup_task!(server::Server)
    entry = lock(SERVER_CLEANUP_LOCK) do
        pop!(SERVER_CLEANUP_TASKS, server, nothing)
    end
    isnothing(entry) && return
    task, timer = entry
    close(timer)
    # Cleanup can run user on_close callbacks that close this server. Never
    # wait for ourselves, nor hold the registry lock while joining the task.
    task === current_task() || wait(task)
    return
end

function setup_connection(session::Session, connection::WebSocketConnection)
    connection.session = session
    server = connection.server
    add_cleanup_task!(server)
    HTTPServer.websocket_route!(server, "/$(session.id)" => connection)
    proxy_url = HTTPServer.relative_url(server, "")
    return setup_websocket_connection_js(proxy_url, session)
end

function setup_connection(session::Session{WebSocketConnection})
    return setup_connection(session, session.connection)
end
