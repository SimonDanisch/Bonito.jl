# TODO, make sure that names are unique
"""
    dependency_path(paths...)

Path to serve downloaded dependencies
"""
dependency_path(paths...) = joinpath(@__DIR__, "..", "js_dependencies", paths...)

mediatype(asset::Asset) = asset.media_type

const server_proxy_url = Ref{String}()

function url(asset::Asset)
    if !isempty(asset.online_path)
        return asset.online_path
    else
        return server_proxy_url[] * AssetRegistry.register(asset.local_path)
    end
end

"""
    Asset(path_onload::Pair{String, JSCode})

Convenience constructor to make `Asset.(["path/to/asset" => js"onload"])`` work!
"""
Asset(path_onload::Pair{String, JSCode}) = Asset(path_onload...)

function Asset(online_path::String, onload::Union{Nothing, JSCode} = nothing)
    local_path = ""; real_online_path = ""
    if is_online(online_path)
        local_path = try
            #download(online_path, dependency_path(basename(online_path)))
            ""
        catch e
            @warn "Download for $online_path failed" exception=e
            local_path = ""
        end
        real_online_path = online_path
    else
        local_path = online_path
    end
    return Asset(Symbol(getextension(online_path)), real_online_path, local_path, onload)
end

"""
    getextension(path)
Get the file extension of the path.
The extension is defined to be the bit after the last dot, excluding any query
string.
# Examples
```julia-repl
julia> WebIO.getextension("foo.bar.js")
"js"
julia> WebIO.getextension("https://my-cdn.net/foo.bar.css?version=1")
"css"
```
"""
getextension(path) = lowercase(last(split(first(split(path, "?")), ".")))

"""
    islocal(path)
Determine whether or not the specified path is a local filesystem path (and not
a remote resource that is hosted on, for example, a CDN).
"""
is_online(path) = any(startswith.(path, ("//", "https://", "http://", "ftp://")))

function Dependency(name::Symbol, urls::AbstractVector)
    Dependency(
        name,
        Asset.(urls),
    )
end

function serialize_string(io::IO, assets::Set{Asset})
    for asset in assets
        serialize_string(io, asset)
        println(io)
    end
end

function serialize_string(io::IO, asset::Asset)
    if mediatype(asset) == :js
        println(
            io,
            "<script src='$(url(asset))'></script>"
        )
    elseif mediatype(asset) == :css
        println(
            io,
            "<link href = $(repr(url(asset))) rel = \"stylesheet\",  type=\"text/css\">"
        )
    else
        error("Unrecognized asset media type: $(mediatype(asset))")
    end
end

function serialize_string(io::IO, dependency::Dependency)
    print(io, dependency.name)
end

# With this, one can just put a dependency anywhere in the dom to get loaded
function jsrender(session::Session, x::Dependency)
    push!(session, x)
    # TODO implement returning nothing to just not be in the dom directly
    div(display = "none", visibility = "hidden")
end

const JSCallLib = Asset("https://simondanisch.github.io/JSServe.jl/js_dependencies/core.js")
