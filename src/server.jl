
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
    return idx === nothing
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

function apply_handler(f, args...)
    return f(args...)
end

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

function websocket_request()
    headers = [
        "Host" => "localhost",
        "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:68.0) Gecko/20100101 Firefox/68.0",
        "Accept" => "*/*",
        "Accept-Encoding" => "gzip, deflate, br",
        "Accept-Language" => "de,en-US;q=0.7,en;q=0.3",
        "Cache-Control" => "no-cache",
        "Connection" => "keep-alive, Upgrade",
        "Dnt" => "1",
        "Origin" => "https://localhost",
        "Pragma" => "no-cache",
        "Sec-Websocket-Extensions" => "permessage-deflate",
        "Sec-Websocket-Key" => "BL3d8I8KC5faPjubRM0riA==",
        "Sec-Websocket-Version" => "13",
        "Upgrade" => "websocket",
    ]
    msg = HTTP.Request(
        "GET",
        "/",
        headers,
        UInt8[],
        parent = nothing,
        version = v"1.1.0"
    )
    return Stream(msg, IOBuffer())
end

"""
warmup(application::Server)

Warms up the application, by sending a couple of request.
"""
function warmup(application::Server)
    yield() # yield to server task to give it a chance to get started
    task = application.server_task[]
    if Base.istaskdone(task)
        error("Webserver doesn't serve! Error: $(fetch(task))")
    end
    # Make a websocket request
    stream = websocket_request()
    try
        @async stream_handler(application, stream)
        write(stream, "blaaa")
    catch e
        # TODO make it not error so we can test this properly
        # This will error, since its not a propper websocket request
        @debug "Error in stream_handler" exception=e
    end
    target = register_local_file(JSServeLib.assets[1].local_path) # http target part
    asset_url = local_url(application, target)
    request = Request("GET", target)

    delegate(application.routes, application, request)

    if Base.istaskdone(task)
        error("Webserver doesn't serve! Error: $(fetch(task))")
    end
    resp = WebSockets.HTTP.get(asset_url, readtimeout=500, retries=1)
    if resp.status != 200
        error("Webserver didn't start succesfully")
    end
    return
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

const MATCH_HEX = r"[\da-f]"
const MATCH_UUID4 = MATCH_HEX^8 * r"-" * (MATCH_HEX^4 * r"-")^3 * MATCH_HEX^12
const MATCH_SESSION_ID = MATCH_UUID4 * r"/" * MATCH_HEX^4

"""
Server(
        dom, url::String, port::Int;
        verbose = false
    )

Creates an application that manages the global server state!
"""
function Server(
        app::App, url::String, port::Int;
        verbose = false,
        routes = Routes(
            "/" => app,
            r"/assetserver/" * MATCH_HEX^40 * r"-.*" => file_server,
            r".*" => (context)-> response_404()
        ),
        websocket_routes = Routes(
            r"/" * MATCH_SESSION_ID => websocket_handler
        )
    )

    application = Server(
        url, port, Dict{String, Dict{String, Session}}(),
        Ref{Task}(), Ref{TCPServer}(),
        routes,
        websocket_routes
    )

    try
        start(application; verbose=verbose)
        # warmup server!
        warmup(application)
    catch e
        close(application)
        rethrow(e)
    end

    return application
end

function Server(
        app, url::String, port::Int; kw...
    )
    Server(App(app), url, port; kw...)
end


function isrunning(application::Server)
    return (isassigned(application.server_task) &&
        isassigned(application.server_connection) &&
        !istaskdone(application.server_task[]) &&
        isopen(application.server_connection[]))
end

function Base.close(application::Server)
    # Closing the io connection should shut down the HTTP listen loop
    for (id, session) in application.sessions
        close(session)
    end

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
    # Sometimes, the first request after closing will still go through
    # see: https://github.com/JuliaWeb/HTTP.jl/pull/494
    # We need to make sure, that we are the ones making this request,
    # So that a newly opened connection won't get a faulty response from this server!
    try
        app_url = local_url(application, "/")
        while true
            x = HTTP.get(app_url, readtimeout=1, retries=1)
            x.status != 200 && break # we got a bad request, maining server is closed!
        end
    catch e
        # This is expected to fail!
        @debug "Failed get request successfully after closing server!" exception=e
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

function insert_session!(server::Server, session=Session())
    server.sessions[session.id] = session
    return session
end

"""Wait on the server task, i.e. block execution by bringing the server event loop to the foreground."""
function Base.wait(server::Server)
    wait(server.server_task[])
end
