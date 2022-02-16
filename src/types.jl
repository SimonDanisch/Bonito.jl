
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
"""
struct Asset
    name::Union{Nothing, String}
    es6module::Bool
    media_type::Symbol
    # We try to always have online & local files for assets
    # If you only give an online resource, we will download it
    # to also be able to host it locally
    online_path::String
    local_path::Union{String, Path}
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

abstract type FrontendConnection end
struct NoConnection <: FrontendConnection end
abstract type AbstractAssetServer end

"""
A web session with a user
"""
struct Session{Connection <: FrontendConnection}
    id::String
    # The connection to the JS frontend.
    # Currently can be IJuliaConnection, WebsocketConnection, PlutoConnection, NoConnection
    connection::Connection
    # The way we serve any file asset
    asset_server::AbstractAssetServer
    # Bool -> if already registered with Frontend
    observables::Dict{String, Tuple{Bool, Observable}}
    message_queue::Vector{Dict{Symbol, Any}}
    # Code that gets evalued last after all other messages, when session gets connected
    on_document_load::Vector{JSCode}
    js_fully_loaded::Channel{Bool}
    on_connection_ready::Any
    # Should be checkd on js_fully_loaded to see if an error occured
    init_error::Ref{Union{Nothing, JSException}}
    js_comm::Observable{Union{Nothing, Dict{String, Any}}}
    on_close::Observable{Bool}
    deregister_callbacks::Vector{Observables.ObserverFunction}
    content_identity::Dict{String, Any}
end

struct Routes
    table::Vector{Pair{Any, Any}}
end

"""
The application one serves
"""
struct Server
    url::String
    port::Int
    server_task::Ref{Task}
    server_connection::Ref{TCPServer}
    routes::Routes
    websocket_routes::Routes
end
