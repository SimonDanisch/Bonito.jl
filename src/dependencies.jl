
const ASSET_REGISTRY = Dict{String, String}()

function unique_file_key(path::String)
    return "/assetserver/" * bytes2hex(sha1(abspath(path))) * "-" * basename(path)
end

function register_local_file(file::String)
    target = normpath(abspath(expanduser(file)))
    key = unique_file_key(target)
    get!(()-> target, ASSET_REGISTRY, key)
    return key
end

function is_key_registered(key::String)
    return haskey(ASSET_REGISTRY, key)
end

function assetserver_to_localfile(key::String)
    path = get(ASSET_REGISTRY, key, nothing)
    if path === nothing
        error("Key does not map to a local path (is not registered via `register_local_file`): $(key)")
    end
    return path
end

include("mimetypes.jl")

function file_server(context)
    path = context.request.target
    if is_key_registered(path)
        filepath = assetserver_to_localfile(path)
        if isfile(filepath)
            header = ["Access-Control-Allow-Origin" => "*",
                      "Content-Type" => file_mimetype(filepath)]
            return HTTP.Response(200, header, body = read(filepath))
        end
    end
    return HTTP.Response(404)
end

"""
    dependency_path(paths...)

Path to serve downloaded dependencies
"""
dependency_path(paths...) = joinpath(@__DIR__, "..", "js_dependencies", paths...)

mediatype(asset::Asset) = asset.media_type

const server_proxy_url = Ref("")

function url(str::String)
    return server_proxy_url[] * str
end

function url(asset::Asset)
    if !isempty(asset.online_path)
        return asset.online_path
    else
        return url(register_local_file(asset.local_path))
    end
end

function Base.show(io::IO, asset::Asset)
    print(io, url(asset))
end

function Asset(online_path::String, onload::Union{Nothing, JSCode} = nothing)
    local_path = ""; real_online_path = ""
    if is_online(online_path)
        local_path = ""
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
julia> JSServe.getextension("foo.bar.js")
"js"
julia> JSServe.getextension("https://my-cdn.net/foo.bar.css?version=1")
"css"
```
Taken from WebIO.jl
"""
getextension(path) = lowercase(last(split(first(split(path, "?")), ".")))

"""
    is_online(path)

Determine whether or not the specified path is a local filesystem path (and not
a remote resource that is hosted on, for example, a CDN).
"""
is_online(path) = any(startswith.(path, ("//", "https://", "http://", "ftp://")))

function Dependency(name::Symbol, urls::AbstractVector)
    return Dependency(name, Asset.(urls), Dict{Symbol, JSCode}())
end

# With this, one can just put a dependency anywhere in the dom to get loaded
function jsrender(session::Session, x::Dependency)
    push!(session, x)
    return nothing
end

function jsrender(session::Session, asset::Asset)
    register_resource!(session, asset)
    return nothing
end

const JSCallLibLocal = Asset(dependency_path("core.js"))

const MsgPackLib = Asset(dependency_path("msgpack.min.js"))

const MarkdownCSS = Asset(dependency_path("markdown.css"))
