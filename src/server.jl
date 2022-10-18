
struct Routes
    table::Vector{Pair{Any, Any}}
end

"""
HTTP server with websocket & http routes
"""
struct Server
    url::String
    port::Int
    server_task::Ref{Task}
    server_connection::Ref{TCPServer}
    routes::Routes
    websocket_routes::Routes
end

function Routes(pairs::Pair...)
    return Routes([pairs...])
end

# Priorities, so that e.g. r".*" doesn't catch absolut matches by e.g a string
pattern_priority(x::Pair) = pattern_priority(x[1])
pattern_priority(x::String) = 1
pattern_priority(x::Tuple) = 2
pattern_priority(x::Regex) = 3

function Base.setindex!(routes::Routes, f, pattern)
    idx = findfirst(pair-> pair[1] == pattern, routes.table)
    if idx !== nothing
        routes.table[idx] = pattern => f
    else
        push!(routes.table, pattern => f)
    end
    # Sort for priority so that exact string matches come first
    sort!(routes.table, by = pattern_priority)
    # return if it was inside already!
    return isnothing(idx)
end

function route!(application::Server, pattern_f::Pair)
    application.routes[pattern_f[1]] = pattern_f[2]
end

function route!(f, application::Server, pattern)
    route!(application, pattern => f)
end

function websocket_route!(application::Server, pattern_f::Pair)
    application.websocket_routes[pattern_f[1]] = pattern_f[2]
end

apply_handler(f, args...) = f(args...)

function apply_handler(chain::Tuple, context, args...)
    f = first(chain)
    result = f(args...)
    return apply_handler(Base.tail(chain), context, result...)
end

function apply_handler(app::App, context)
    server = context.application
    session = insert_session!(server)
    html_dom = Base.invokelatest(app.handler, session, context.request)
    return html(page_html(session, html_dom))
end

function delegate(routes::Routes, application, request::Request, args...)
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
    # If no route is found we have a classic case of 404!
    # What a classic this response!
    return response_404("Didn't find route for $(request.target)")
end

function match_request(pattern::String, request)
    return request.target == pattern ? pattern : nothing
end

function match_request(pattern::Regex, request)
    return match(pattern, request.target)
end

"""
    local_url(server::Server, url)

The local url to reach the server, on the server
"""
function local_url(server::Server, url)
    return string("http://", server.url, ":", server.port, url)
end

"""
    online_url(server::Server, url)
The url to connect to the server from the internet.
Needs to have `JSSERVE_CONFIGURATION.external_url` set to the IP or dns route of the server
"""
function online_url(server::Server, url)
    base_url = JSSERVE_CONFIGURATION.external_url[]
    if isempty(base_url)
        local_url(server, url)
    else
        base_url * url
    end
end

function stream_handler(application::Server, stream::Stream)
    if WebSockets.is_upgrade(stream)
        try
            WebSockets.upgrade(stream) do request, websocket
                delegate(
                    application.websocket_routes, application, request, websocket
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
    http_handler = HTTP.RequestHandlerFunction() do request
        delegate(
            application.routes, application, request,
        )
    end
    try
        HTTP.handle(http_handler, stream)
    catch e
        # we expect the IOError to happen, if either the page gets closed
        # or we close the server!
        if !(e isa Base.IOError && e.msg == "stream is closed or unusable")
            rethrow(e)
        end
    end
end


"""
Server(
        dom, url::String, port::Int;
        verbose = false
    )

Creates an application that manages the global server state!
"""
function Server(
        url::String, port::Int;
        verbose = false,
        routes = Routes(),
        websocket_routes = Routes()
    )
    server = Server(
        url, port,
        Ref{Task}(), Ref{TCPServer}(),
        routes,
        websocket_routes
    )

    try
        start(server; verbose=verbose)
    catch e
        close(server)
        rethrow(e)
    end

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
        try
            wait(application.server_task[])
            @assert !Base.isdone(application.server_connection[])
        catch e
            @debug "Server task failed with an (expected) exception on close" exception=e
        end
    end
    @assert !isrunning(application)
end

function start(application::Server; verbose=false)
    isrunning(application) && return
    address = Sockets.InetAddr(Sockets.getaddrinfo(application.url), application.port)
    ioserver = Sockets.listen(address)
    application.server_connection[] = ioserver
    # pass tcp connection to listen, so that we can close the server
    application.server_task[] = @async HTTP.listen(
            application.url, application.port; server=ioserver, verbose=verbose
        ) do stream::Stream
        Base.invokelatest(stream_handler, application, stream)
    end
    return
end

const GLOBAL_SERVER = Ref{Server}()

function get_server()
    if !isassigned(GLOBAL_SERVER) || istaskdone(GLOBAL_SERVER[].server_task[])
        GLOBAL_SERVER[] = Server(
            App("Nothing to see"),
            JSSERVE_CONFIGURATION.listen_url[],
            JSSERVE_CONFIGURATION.listen_port[],
            verbose=JSSERVE_CONFIGURATION.verbose[]
        )
    end
    return GLOBAL_SERVER[]
end

const JSSERVE_CONFIGURATION = (
    # The URL used to which the default server listens to
    listen_url = Ref("localhost"),
    # The Port to which the default server listens to
    listen_port = Ref(9284),
    # The url Javascript uses to connect to the websocket.
    # if empty, it will use:
    # `window.location.protocol + "//" + window.location.host`
    external_url = Ref(""),
    # The url prepended to assets when served!
    # if `""`, urls are inserted into HTML in relative form!
    content_delivery_url = Ref(""),
    # Verbosity for logging!
    verbose = Ref(false)
)

"""
    configure_server!(;
            listen_url::String=JSSERVE_CONFIGURATION.listen_url[],
            listen_port::Integer=JSSERVE_CONFIGURATION.listen_port[],
            forwarded_port::Integer=listen_port,
            external_url=nothing,
            content_delivery_url=nothing
        )

Configures the parameters for the automatically started server.

    Parameters:

    * listen_url=JSSERVE_CONFIGURATION.listen_url[]
        The address the server listens to.
        must be 0.0.0.0, 127.0.0.1, ::, ::1, or localhost.
        If not set differently by an ENV variable, will default to 127.0.0.1

    * listen_port::Integer=JSSERVE_CONFIGURATION.listen_port[],
        The Port to which the default server listens to
        If not set differently by an ENV variable, will default to 9284

    * forwarded_port::Integer=listen_port,
        if port gets forwarded to some other port, set it here!

    * external_url=nothing
        The url from which the server is reachable.
        If served on "127.0.0.1", this will default to http://localhost:forwarded_port
        if listen_url is "0.0.0.0", this will default to http://\$(Sockets.getipaddr()):forwarded_port
        so that the server is reachable inside the local network.
        If the server should be reachable from some external dns server,
        this needs to be set here.

    * content_delivery_url=nothing
        You can server files from another server.
        Make sure any file referenced from Julia is reachable at
        content_delivery_url * "/the_file"
"""
function configure_server!(;
        listen_url=nothing,
        # The Port to which the default server listens to
        listen_port::Integer=JSSERVE_CONFIGURATION.listen_port[],
        # if port gets forwarded to some other port, set it here!
        forwarded_port::Integer=listen_port,
        # The url from which the server is reachable.
        # If served on "127.0.0.1", this will default to
        # if listen_url is "0.0.0.0", this will default to
        # Sockets.getipaddr() so that it's the ip address in the local network.
        # If the server should be reachable from some external dns server,
        # this needs to be set here
        external_url=nothing,
        # You can server files from another server.
        # Make sure any file referenced from Julia is reachable at
        # content_delivery_url * "/the_file"
        content_delivery_url=nothing
    )

    if isnothing(listen_url)
        if !isnothing(external_url)
            # if we serve to an external url, server must listen to 0.0.0.0
            listen_url = "0.0.0.0"
        else
            listen_url = JSSERVE_CONFIGURATION.listen_url[]
        end
    end

    if isnothing(external_url)
        if listen_url == "0.0.0.0"
            external_url = string(Sockets.getipaddr(), ":$forwarded_port")
        elseif listen_url in ("127.0.0.1", "localhost")
            external_url = "http://localhost:$forwarded_port"
        else
            error("Trying to listen to $(listen_url), while only \"127.0.0.1\", \"0.0.0.0\" and \"localhost\" are supported")
        end
    end
    # set the config!
    JSSERVE_CONFIGURATION.listen_url[] = listen_url
    JSSERVE_CONFIGURATION.external_url[] = external_url
    JSSERVE_CONFIGURATION.listen_port[] = listen_port
    if content_delivery_url === nothing
        JSSERVE_CONFIGURATION.content_delivery_url[] = external_url
    else
        JSSERVE_CONFIGURATION.content_delivery_url[] = content_delivery_url
    end
    return
end

function server_defaults()
     url = if haskey(ENV, "JULIA_WEBIO_BASEURL")
        ENV["JULIA_WEBIO_BASEURL"]
    else
        ""
    end
    if endswith(url, "/")
        url = url[1:end-1]
    end
    JSSERVE_CONFIGURATION.listen_url[] = get(ENV, "JSSERVE_LISTEN_URL", "127.0.0.1")
    JSSERVE_CONFIGURATION.external_url[] = url
    JSSERVE_CONFIGURATION.content_delivery_url[] = url

    if haskey(ENV, "WEBIO_HTTP_PORT")
        JSSERVE_CONFIGURATION.listen_port[] = parse(Int, ENV["WEBIO_HTTP_PORT"])
    end

end
