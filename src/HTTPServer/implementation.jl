struct Routes
    table::Vector{Pair{Any, Any}}
    lock::Base.ReentrantLock
end

"""
HTTP server with websocket & http routes
"""
mutable struct Server
    url::String
    port::Int
    # If behind a proxy, this is the url content is served after the proxy
    proxy_url::String
    server_task::Ref{Task}
    server_connection::Ref{TCPServer}
    routes::Routes
    websocket_routes::Routes
    protocol
end

Routes(pairs::Pair...) = Routes(Pair{Any, Any}[pairs...], Base.ReentrantLock())

# Priorities, so that e.g. r".*" doesn't catch absolut matches by e.g a string
pattern_priority(x::Pair) = pattern_priority(x[1])
pattern_priority(x::String) = 1
pattern_priority(x::Tuple) = 2
pattern_priority(x::Regex) = 3

delete_route!(server::Server, pattern) = delete_route!(server.routes, pattern)
delete_websocket_route!(server::Server, pattern) = delete_route!(server.websocket_routes, pattern)

function delete_route!(routes::Routes, pattern)
    lock(routes.lock) do
        filter!(((key, f),) -> !(key == pattern), routes.table)
    end
    return
end

function get_route(routes::Routes, pattern)
    lock(routes.lock) do
        for (key, route) in routes.table
            key == pattern && return route
        end
        return nothing
    end
end

function has_route(routes::Routes, pattern)
    lock(routes.lock) do
        return any(x -> x[1] == pattern, routes.table)
    end
end

function route!(routes::Routes, pattern_func::Pair)
    pattern, func = pattern_func
    return lock(routes.lock) do
        idx = findfirst(pair-> pair[1] == pattern, routes.table)
        old = nothing
        if idx !== nothing
            old = routes.table[idx][2]
            routes.table[idx] = pattern_func
        else
            push!(routes.table, pattern_func)
        end
        # Sort for priority so that exact string matches come first
        sort!(routes.table, by = pattern_priority)
        # return old route (nothing if new)
        return old
    end
end

function route!(application::Server, pattern_func::Pair)
    return route!(application.routes, pattern_func)
end
function websocket_route!(application::Server, pattern_func::Pair)
    route!(application.websocket_routes, pattern_func)
end

function route!(func, application::Server, pattern)
    route!(application, Pair{Any, Any}(pattern, func))
end

apply_handler(f, args...) = f(args...)

function apply_handler(chain::Tuple, context, args...)
    f = first(chain)
    result = f(args...)
    return apply_handler(Base.tail(chain), context, result...)
end

function delegate(routes::Routes, application, request::Request, args...)
    try
        for (pattern, f) in routes.table
            match = match_request(pattern, request)
            if match !== nothing
                context = (
                    routes = routes,
                    application = application,
                    request = request,
                    match = match
                )
                return apply_handler(f, context, args...)
            end
        end
        @debug("Didn't find route for $(request.target)")
        # If no route is found we have a classic case of 404!
        # What a classic this response!
        return response_404("Didn't find route for $(request.target)")
    catch e
        return response_500(CapturedException(e, Base.catch_backtrace()))
    end
end

function match_request(pattern::String, request)
    request.target == pattern && return pattern
    uri = URI(request.target)
    uri.path == pattern && return pattern
    return nothing
end

function match_request(pattern::Regex, request)
    return match(pattern, request.target)
end

"""
    local_url(server::Server, url)

The local url to reach the server, on the server
"""
function local_url(server::Server, url)
    # TODO, tell me again, why electron only accepts localhost in the url?
    # And is there a clean way to "normalize" an url like that, so that no one complains?
    base_url = replace(server.url, r"(127.0.0.1)|(0.0.0.0)" => "localhost")
    return string(server.protocol, base_url, ":", server.port, url)
end

"""
    online_url(server::Server, url)

The url to connect to the server from the internet.
Needs to have `server.proxy_url` set to the IP or dns route of the server
"""
function online_url(server::Server, url)
    base_url = server.proxy_url
    if isempty(base_url)
        return local_url(server, url)
    else
        return base_url * url
    end
end

function stream_handler(application::Server, stream::Stream)
    if HTTP.WebSockets.isupgrade(stream.message)
        try
            HTTP.WebSockets.upgrade(stream; binary=true) do ws
                delegate(
                    application.websocket_routes, application, stream.message, ws
                )
            end
            return
        catch e
            # When browser closes we may get an io error here!
            if !(e isa Base.IOError)
                rethrow(e)
            end
        end
    end
    http_handler = HTTP.streamhandler() do request
        delegate(
            application.routes, application, request,
        )
    end
    try
        http_handler(stream)
    catch e
        # we expect the IOError to happen, if either the page gets closed
        # or we close the server!
        if !(e isa Base.IOError && (e.msg == "stream is closed or unusable" || e.code == -4081))
            rethrow(e)
        end
    end
end

"""
Server(
        dom, url::String, port::Int;
        verbose = -1
    )

Creates an application that manages the global server state!
"""
function Server(
        url::String, port::Int;
        verbose = -1,
        proxy_url = "",
        routes = Routes(),
        websocket_routes = Routes(),
	listener_kw...
    )
    server = Server(
        url, port, proxy_url,
        Ref{Task}(), Ref{TCPServer}(),
        routes,
        websocket_routes,
	haskey(listener_kw, :sslconfig) ? "https://" : "http://"
    )

    try
        start(server; verbose=verbose, listener_kw...)
    catch e
        close(server)
        rethrow(e)
    end
    return server
end

function Server(
        app::Union{Function, App},
        url::String, port::Int;
        verbose=-1, proxy_url="",
	listener_kw...
    )
    server = Server(url, port; verbose=verbose, proxy_url=proxy_url, listener_kw...)
    route!(server, "/" => app)
    return server
end

function isrunning(application::Server)
    return (isassigned(application.server_task) &&
        isassigned(application.server_connection) &&
        !istaskdone(application.server_task[]) &&
        isopen(application.server_connection[]))
end

function Base.close(application::Server)
    if isassigned(application.server_connection)
        close(application.server_connection[])
        @assert !isopen(application.server_connection[])
    end
    # For good measures, wait until the task finishes!
    if isassigned(application.server_task)
        task = application.server_task[]
        try
            # Somehow wait(task) deadlocks when there is still an open page?
            # Really weird, especially since I can't make an MWE ... (Windows, Julia 1.8.2, HTTP@v1.5.5)
            # TODO, do we hold on to resources in the stream handler??
            Bonito.wait_for(() -> istaskdone(task))
            @assert !Base.istaskdone(task)
        catch e
            @debug "Server task failed with an (expected) exception on close" exception=e
        end
    end
    @assert !isrunning(application)
end


function try_listen(url, port)
    address = Sockets.InetAddr(Sockets.getaddrinfo(url), port)
    try
        ioserver = Sockets.listen(address)
        return port, ioserver
    catch e
        if e isa Base.IOError
            #address already in use
            if e.code == Base.UV_EADDRINUSE
                return try_listen(url, port+1)
            end
        end
        rethrow(e)
    end
end

function start(server::Server; verbose=-1, listener_kw...)
    isrunning(server) && return

    newport, ioserver = try_listen(server.url, server.port)
    if server.port != newport
        @warn "Port in use, using different port. New port: $(newport)"
        server.port = newport
    end

    server.server_connection[] = ioserver
    # pass tcp connection to listen, so that we can close the server

    listener = HTTP.Servers.Listener(ioserver; listener_kw...)
    server.server_task[] = @async begin
        http_server = HTTP.listen!(listener; verbose=verbose) do stream::Stream
            Base.invokelatest(stream_handler, server, stream)
        end
        try
            wait(http_server)
        finally
            # try to gracefully close
            close(http_server)
        end
    end
    return
end

"""
    wait(server::Server)

Wait on the server task, i.e. block execution by bringing the server event loop to the foreground.
"""
function Base.wait(server::Server)
    wait(server.server_task[])
end

function get_error(server::Server)
    # Running server has no problems!
    isrunning(server) && return nothing
    !istaskfailed(server.server_task[]) && return nothing
    try
        return fetch(server.server_task[])
    catch e
        return e
    end
end

function show_server(io::IO, server::Server)
    println(io, "Server:")
    println(io, "  isrunning: $(isrunning(server))")
    println(io, "  listen_url: $(local_url(server, ""))")
    println(io, "  online_url: $(online_url(server, ""))")
    println(io, "  http routes: ", length(server.routes.table))
    if !isempty(server.routes.table)
        for (route, app) in server.routes.table
            println(io, "    ", route, " => ", typeof(app))
        end
    end
    println(io, "  websocket routes: ", length(server.websocket_routes.table))
    if !isempty(server.websocket_routes.table)
        for (route, app) in server.websocket_routes.table
            println(io, "    ", route, " => ", typeof(app))
        end
    end
    err = get_error(server)
    if !isnothing(err)
        print(io, "  error: ")
        Base.showerror(io, err)
        println(io)
    end
end

Base.show(io::IO, ::MIME"text/plain", server::Server) = show_server(io, server)
Base.show(io::IO, server::Server) = show_server(io, server)
