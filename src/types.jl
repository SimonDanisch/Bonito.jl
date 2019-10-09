"""
The string part of JSCode.
"""
struct JSString
    source::String
end

"""
Javascript code that supports interpolation of Julia Objects.
Construction of JSCode via string macro:
```julia
jsc = js"console.log(\$(some_julia_variable))"
```
This will decompose into:
```julia
jsc.source == [JSString("console.log("), some_julia_variable, JSString("\"")]
```
"""
struct JSCode
    source::Vector{Union{JSString, Any}}
end


"""
Represent an asset stored at an URL.
We try to always have online & local files for assets
If one gives an online resource, it will be downloaded, to host it locally.
"""
struct Asset
    media_type::Symbol
    # We try to always have online & local files for assets
    # If you only give an online resource, we will download it
    # to also be able to host it locally
    online_path::String
    local_path::String
    onload::Union{Nothing, JSCode}
end

"""
Encapsulates frontend dependencies. Can be used in the following way:

```Julia
const noUiSlider = Dependency(
    :noUiSlider,
    # js & css dependencies are supported
    [
        "https://cdn.jsdelivr.net/gh/leongersen/noUiSlider/distribute/nouislider.min.js",
        "https://cdn.jsdelivr.net/gh/leongersen/noUiSlider/distribute/nouislider.min.css"
    ]
)
# use the dependency on the frontend:
evaljs(session, js"\$(noUiSlider).some_function(...)")
```
jsrender will make sure that all dependencies get loaded.
"""
struct Dependency
    name::Symbol # The JS Module name that will get loaded
    assets::Vector{Asset}
end


"""
A web session with a user
"""
struct Session
    connection::Ref{WebSocket}
    observables::Dict{String, Tuple{Bool, Observable}} # Bool -> if already registered with Frontend
    message_queue::Vector{Dict{Symbol, Any}}
    dependencies::Set{Asset}
    on_document_load::Vector{JSCode}
end


"""
The application one serves
"""
struct Application
    url::String
    port::Int
    sessions::Dict{String, Session}
    server_task::Ref{Task}
    server_connection::Ref{TCPServer}
    dom::Function
end


WebSockets.getrawstream(io::IO) = io

function websocket_request()
    headers = [
        "Host" => "127.0.0.1",
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

function warmup(application)
    yield() # yield to server task to give it a chance to get started
    task = application.server_task[]
    if Base.istaskdone(task)
        error("Webserver doesn't serve! Error: $(fetch(task))")
    end
    # Make a websocket request
    stream = websocket_request()
    try
        stream_handler(application, stream)
    catch e
        # TODO make it not error so we can test this properly
        # This will error, since its not a propper websocket request
        @debug "Error in stream_handler" exception=e
    end

    bundle_url = url(JSCallLibLocal)

    request = Request("GET", AssetRegistry.register(JSCallLibLocal.local_path))
    http_handler(application, request)

    wait_time = 10.0; start = time() # wait for max 10 s
    success = false
    while time() - start < wait_time
        # Block as long as our server doesn't actually serve the bundle
        if Base.istaskdone(task)
            error("Webserver doesn't serve! Error: $(fetch(task))")
            break
        end
        # async + fetch allows the server to do work while the request gets sent!
        resp = fetch(@async WebSockets.HTTP.get(bundle_url))
        if resp.status == 200
            success = true
            break
        end
        sleep(0.1)
    end
    if !success
        error("Waited $(wait_time)s for webserver to start up, and didn't receive any response")
    end
end

function stream_handler(application::Application, stream::Stream)
    if WebSockets.is_upgrade(stream)
        WebSockets.upgrade(stream) do request, websocket
            websocket_handler(application, request, websocket)
        end
        return
    end
    f = HTTP.RequestHandlerFunction() do request
        http_handler(application, request)
    end
    HTTP.handle(f, stream)
end


"""
Application(
        dom, url::String, port::Int;
        verbose = false
    )

Creates an application that manages the global server state!
"""
function Application(
        dom, url::String, port::Int;
        verbose = false
    )

    application = Application(
        url, port, Dict{String, Session}(),
        Ref{Task}(), Ref{TCPServer}(), dom
    )
    start(application)
    # warmup server!
    warmup(application)

    return application
end

function isrunning(application::Application)
    return (isassigned(application.server_task) &&
        isassigned(application.server_connection) &&
        !istaskdone(application.server_task[]) &&
        isopen(application.server_connection[]))
end

function Base.close(application::Application)
    # Closing the io connection should shut down the HTTP listen loop
    close(application.server_connection[])
    # For good measures, wait until the task finishes!
    try
        wait(application.server_task[])
    catch e
        # the wait will throw with the below exception
        if !(e isa TaskFailedException && e.task.exception.code == -4079)
            rethrow(e)
        end
    end
end
function start(application::Application)
    isrunning(application) && return
    address = Sockets.InetAddr(
        parse(Sockets.IPAddr, application.url), application.port
    )
    ioserver = Sockets.listen(address)
    application.server_connection[] = ioserver
    # pass tcp connection to listen, so that we can close the server
    application.server_task[] = @async HTTP.listen(
            application.url, application.port, server = ioserver
        ) do stream::Stream
        Base.invokelatest(stream_handler, application, stream)
    end
    return
end
