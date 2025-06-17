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
    # "." -> relative urls to the site it's served to
    # "" -> use local url (e.g 0.0.0.0:8081)
    proxy_url::Union{String, Nothing}
    server::Union{Nothing, HTTP.Servers.Server}
    routes::Routes
    websocket_routes::Routes
    protocol::String
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

function linkify_stacktrace(error_msg, bt::String)
    lines = split(bt, '\n'; keepempty=false)  # Split stack trace into lines
    elements = []

    for line in lines
        # Match both Windows (C:\path\file.jl:123) and Unix (/path/file.jl:123) paths
        m = match(r"^(.*?)([A-Za-z]:[\\/][^\s]+\.jl|\.[\\/][^\s]+\.jl):(\d+)(.*)", line)
        if m !== nothing
            prefix, file, line_num, suffix = m.captures
            normalized_file = replace(file, "\\" => "/")  # Convert Windows paths to `/`
            vscode_url = "vscode://file/" * normalized_file * ":" * line_num  # VS Code link
            push!(
                elements,
                DOM.span(
                    String(prefix),
                    DOM.a(file * ":" * line_num; href=vscode_url),
                    String(suffix),
                ),
                DOM.br(),
            )
        else
            m2 = match(r"^(.*?)(\[\d+\])", line)
            if !isnothing(m2)
                prefix, suffix = m2.captures
                push!(
                    elements,
                    DOM.span(String(line); style="color: darkred; font-weight: bold;"),
                    DOM.br(),
                )  # Normal line
            else
                push!(elements, DOM.span(String(line)), DOM.br())  # Normal line
            end
        end
    end
    return DOM.pre(
        DOM.h3(error_msg; style="color: red;"),
        elements...;
        class="backtrace",
        style="overflow-x: auto;",
    )
end

function err_to_html(err, stacktrace)
    error_msg = sprint() do io
        Base.showerror(io, err)
    end
    stacktrace_msg = sprint() do io
        iol = IOContext(io, :stacktrace_types_limited => Base.RefValue(true))
        Base.show_backtrace(iol, stacktrace)
    end
    return linkify_stacktrace(error_msg, stacktrace_msg)
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
        stacktrace = Base.catch_backtrace()
        err = CapturedException(e, stacktrace)
        Base.showerror(stderr, err)
        html = err_to_html(e, stacktrace)
        html_str = sprint() do io
            Bonito.print_as_page(io,  html)
        end
        return response_500(html_str)
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

function join_url(base, url)
    base = rstrip(base, '/')
    url = lstrip(url, '/')
    return base * "/" * url
end

"""
    online_url(server::Server, url)

The url to connect to the server from the internet.
Needs to have `server.proxy_url` set to the IP or dns route of the server
"""
function online_url(server::Server, url)
    proxy_url = server.proxy_url
    # Relative urls or
    if proxy_url in (".", "")
        return local_url(server, url)
    else
        return join_url(proxy_url, url)
    end
end

function relative_url(server::Server, url)
    proxy_url = server.proxy_url
    if proxy_url == ""
        # Absolute URLS!
        return online_url(server, url)
    else
        # absolute proxy URLS
        return join_url(proxy_url, url)
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
        nothing,
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

function isrunning(server::Server)
    return !isnothing(server.server) && !istaskdone(server.server.task)
end

function Base.close(server::Server)
    isnothing(server.server) && return
    for (k, web_handler) in server.websocket_routes.table
        try
            close(web_handler)
        catch e
            @warn "Error while closing websocket handler for route $(k)" exception=(e, Base.catch_backtrace())
        end
    end
    close(server.server)
end


function try_listen(url, port, server, verbose; listener_kw...)
    try
        httpserver = HTTP.listen!(url, port; verbose=verbose, listener_kw...) do stream::Stream
            Base.invokelatest(stream_handler, server, stream)
        end
        return port, httpserver
    catch e
        if e isa Base.IOError
            #address already in use
            if e.code == Base.UV_EADDRINUSE
                return try_listen(url, port+1, server, verbose; listener_kw...)
            end
        end
        rethrow(e)
    end
end

function start(server::Server; verbose=-1, listener_kw...)
    isrunning(server) && return
    newport, http_server = try_listen(server.url, server.port, server, verbose; listener_kw...)
    if server.port != newport
        @warn "Port in use, using different port. New port: $(newport)"
        server.port = newport
    end
    server.server = http_server
    return
end

"""
    wait(server::Server)

Wait on the server task, i.e. block execution by bringing the server event loop to the foreground.
"""
function Base.wait(server::Server)
    wait(server.server.task)
end

function get_error(server::Server)
    # Running server has no problems!
    isrunning(server) && return nothing
    !istaskfailed(server.server.task) && return nothing
    try
        return fetch(server.server.task)
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
