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
    dom::Function
end


function Application(
        dom, url::String, port::Int;
        verbose = false
    )
    application = Application(
        url, port, Dict{String, Session}(),
        Ref{Task}(), dom,
    )
    application.server_task[] = @async HTTP.listen(url, port, verbose = verbose) do stream::Stream
        Base.invokelatest(stream_handler, application, stream)
    end
    return application
end
