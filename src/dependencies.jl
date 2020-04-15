
const ASSET_REGISTRY = Dict{String, String}()

function unique_file_key(path::String)
    return bytes2hex(sha1(abspath(path))) * "-" * basename(path)
end

function register_local_file(file::String)
    target = normpath(abspath(expanduser(file)))
    key = "/assetserver/" * unique_file_key(target)
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

function Base.show(io::IO, asset::Asset)
    print(io, url(asset))
end

function Asset(online_path::String, onload::Union{Nothing, JSCode}=nothing; check_isfile=true)
    local_path = ""; real_online_path = ""
    if is_online(online_path)
        local_path = ""
        real_online_path = online_path
    else
        local_path = normpath(abspath(expanduser(online_path)))
        if check_isfile && !isfile(local_path)
            error("File $(local_path) does not exist!")
        end
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

function include_asset(asset::Asset, serializer::UrlSerializer=UrlSerializer())
    file_url = repr(url(asset, serializer))
    if mediatype(asset) == :js
        return "<script src=$(file_url)></script>"
    elseif mediatype(asset) == :css
        return "<link href=$(file_url) rel=\"stylesheet\" type=\"text/css\">"
    else
        error("Unrecognized asset media type: $(mediatype(asset))")
    end
end

function include_asset(assets::Set{Asset}, serializer::UrlSerializer=UrlSerializer())
    return sprint() do io
        for asset in assets
            println(io, include_asset(asset, serializer))
        end
    end
end

function url(str::String, serializer::UrlSerializer=UrlSerializer())
    return url(Asset(str), serializer)
end

function unique_name_in_folder(folder, dream_name)
    taken_names = readdir(folder)
    try_name = dream_name
    unique_id = 1
    # Large number of tries - I would make this a while true
    # but I think its better to have a fixed termination!
    for unique_id in 1:1000000
        if !(try_name in taken_names)
            return try_name
        end
        try_name = string(unique_id, "_", dream_name)
    end
    error("No unique names found after 1000000 tries for name $(dream_name) in $(folder)")
end

function url(asset::Asset, serializer::UrlSerializer=UrlSerializer())
    if isempty(asset.online_path)
        path = asset.local_path
        relative_path = if serializer.assetserver
            # we use assetserver, so we register the local file with the server
            register_local_file(path)
        else
            # we don't use assetserver, so we copy the asset to asset_folder
            # for someone else to serve them!
            if serializer.asset_folder === nothing
                error("Not using assetserver requires to set `asset_folder` to a valid local folder")
            end
            if !isdir(serializer.asset_folder)
                error("`asset_folder` doesn't exist: $(serializer.asset_folder)")
            end
            # make sure we don't get name clashes in asset_folder
            path_base = dirname(path)
            file_name = basename(path)
            unique_file_name = unique_name_in_folder(serializer.asset_folder, file_name)
            unique_path = joinpath(serializer.asset_folder, unique_file_name)
            cp(path, unique_path, force=true)
            unique_file_name
        end
        if serializer.absolute
            # we serve from an absolute URL, so we append the content_delivery_url!
            return serializer.content_delivery_url * relative_path
        else
            return relative_path
        end
    else
        # We dont touch online urls for now
        # we may to decide to download them and add them to the asset_folder
        # if desired
        return asset.online_path
    end
end
