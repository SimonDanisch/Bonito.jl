
"""
    App(handler)

calls handler with the session and the http request object.
f is expected to return a valid DOM object,
so something renderable by jsrender, e.g. `DOM.div`.
"""
struct App
    handler::Function
    function App(handler::Function)
        if hasmethod(handler, Tuple{Session, HTTP.Request})
            return new(handler)
        elseif hasmethod(handler, Tuple{Session})
            return new((session, request) -> handler(session))
        elseif hasmethod(handler, Tuple{HTTP.Request})
            return new((session, request) -> handler(request))
        elseif hasmethod(handler, Tuple{})
           return new((session, request) -> handler())
        else
            error("""
            Handler function must have the following signature:
                handler() -> DOM
                handler(session::Session) -> DOM
                handler(request::Request) -> DOM
                handler(session, request) -> DOM
            """)
        end
    end
    function App(dom_object)
        return new((s, r)-> dom_object)
    end
end

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
    local_path::Union{String, Path}
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
    # The global -> Function name, JSCode -> the actual function code!
    functions::Dict{Symbol, JSCode}
end

"""
    UrlSerializer
Struct used to encode how an url is rendered
Fields:
```julia
# uses assetserver?
assetserver::Bool
# if assetserver == false, we move all assets into asset_folder
# for someone else to serve them!
asset_folder::Union{Nothing, String}

absolute::Bool
# Used to prepend if absolute == true
content_delivery_url::String
```
"""
struct UrlSerializer
    # uses assetserver?
    assetserver::Bool
    # if assetserver == false, we move all assets into asset_folder
    # for someone else to serve them!
    asset_folder::Union{Nothing, String}

    absolute::Bool
    # Used to prepend if absolute == true
    content_delivery_url::String
    # Inlines all content directly into the html
    # Makes all above options obsolete
    inline_all::Bool
end

function UrlSerializer(;
        proxy = JSSERVE_CONFIGURATION.content_delivery_url[],
        assetserver=true, asset_folder=nothing, absolute=proxy!="",
        inline_all=false
    )
    return UrlSerializer(
        assetserver, asset_folder, absolute, proxy, inline_all
    )
end

struct JSException <: Exception
    exception::String
    message::String
    stacktrace::Vector{String}
end

"""
Creates a Julia exception from data passed to us by the frondend!
"""
function JSException(js_data::AbstractDict)
    stacktrace = String[]
    if js_data["stacktrace"] !== nothing
        for line in split(js_data["stacktrace"], "\n")
            push!(stacktrace, replace(line, ASSET_URL_REGEX => replace_url))
        end
    end
    return JSException(js_data["exception"], js_data["message"], stacktrace)
end

function Base.show(io::IO, exception::JSException)
    println(io, "An exception was thrown in JS: $(exception.exception)")
    println(io, "Additional message: $(exception.message)")
    println(io, "Stack trace:")
    for line in exception.stacktrace
        println(io, "    ", line)
    end
end

"""
A web session with a user
"""
struct Session
    # IOBuffer for testing
    connection::Base.RefValue{Union{Nothing, WebSocket, IOBuffer}}
    # Bool -> if already registered with Frontend
    observables::Dict{String, Tuple{Bool, Observable}}
    message_queue::Vector{Dict{Symbol, Any}}
    dependencies::Set{Asset}
    on_document_load::Vector{JSCode}
    id::String
    js_fully_loaded::Channel{Bool}
    on_websocket_ready::Any
    url_serializer::UrlSerializer
    # Should be checkd on js_fully_loaded to see if an error occured
    init_error::Ref{Union{Nothing, JSException}}
    js_comm::Observable{Union{Nothing, Dict{String, Any}}}
    on_close::Observable{Bool}
    deregister_callbacks::Vector{Observables.ObserverFunction}
    unique_object_cache::Dict{String, WeakRef}
end

struct Routes
    table::Vector{Pair{Any, Any}}
end


"""
The application one serves

The server event loop can be brought to the foreground with
`wait(server::Server)`.
"""
struct Server
    url::String
    port::Int
    sessions::Dict{String, Session}
    server_task::Ref{Task}
    server_connection::Ref{TCPServer}
    routes::Routes
    websocket_routes::Routes
end
