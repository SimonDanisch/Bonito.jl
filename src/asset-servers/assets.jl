
mediatype(asset::Asset) = asset.media_type

function get_path(asset::Asset)
    isempty(asset.online_path) ? asset.local_path : asset.online_path
end

function jsrender(session::Session, asset::Asset)
    element = if mediatype(asset) == :js
        DOM.script(src=asset, type="module")
    elseif mediatype(asset) == :css
        DOM.link(href=asset, rel="stylesheet", type="text/css")
    elseif mediatype(asset) in (:jpeg, :jpg, :png)
        DOM.img(src=asset)
    else
        error("Unrecognized asset media type: $(mediatype(asset))")
    end
    return jsrender(session, element)
end

"""
    is_online(path)

Determine whether or not the specified path is a local filesystem path (and not
a remote resource that is hosted on, for example, a CDN).
"""
is_online(path::AbstractString) = any(startswith.(path, ("//", "https://", "http://", "ftp://")))
is_online(path::Path) = false # RelocatableFolders is only used for local filesystem paths

function normalize_path(path::AbstractString; check_isfile=false)
    local_path = normpath(abspath(expanduser(path)))
    if check_isfile && !isfile(local_path)
        error("File $(local_path) does not exist!")
    end
    return local_path
end

# `Path` type handles all normalizations and checks
normalize_path(path::Path; check_isfile=false) = path

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
getextension(path::AbstractString) = lowercase(last(split(first(split(path, "?")), ".")))
getextension(path::Path) = getextension(getroot(path))

function Base.show(io::IO, asset::Asset)
    print(io, get_path(asset))
end

function Asset(online_path::Union{String, Path}; name=nothing, es6module=false, check_isfile=false)
    local_path = ""; real_online_path = ""
    if is_online(online_path)
        local_path = ""
        real_online_path = online_path
    else
        local_path = normalize_path(online_path; check_isfile=check_isfile)
    end
    mediatype = Symbol(getextension(online_path))
    return Asset(name, es6module, mediatype, real_online_path, local_path)
end

function unique_file_key(path::String)
    return bytes2hex(sha1(abspath(path))) * "-" * basename(path)
end

unique_file_key(path) = unique_file_key(string(path))

function ES6Module(path)
    name = String(splitext(basename(path))[1])
    return Asset(path; name=name, es6module=true)
end

function CDNSource(name; user=nothing, version=nothing)
    url = "https://esm.sh/"
    if !isnothing(user)
        url = url * user * "/"
    end
    url = url * name
    if isnothing(version)
        url = "$(url)@$(version)"
    end
    return Asset(url; name=name, es6module=true)
end

function to_data_url(file_path; mime = file_mimetype(file_path))
    isfile(file_path) || error("File not found: $(file_path)")
    return sprint() do io
        print(io, "data:$(mime);base64,")
        iob64_encode = Base64EncodePipe(io)
        open(file_path, "r") do io
            write(iob64_encode, io)
        end
    end
end


"""
    dependency_path(paths...)

Path to serve downloaded dependencies
"""
dependency_path(paths...) = @path joinpath(@__DIR__, "..", "..", "js_dependencies", paths...)

const JSServeLib = ES6Module(JSServe.dependency_path("JSServe.bundle.js"))

include("mimetypes.jl")
include("no-server.jl")
include("http.jl")

function default_asset_server()
    return NoServer()
end

function local_path(path, serializer)
    if serializer.assetserver
        # we use assetserver, so we register the local file with the server
        return register_local_file(path)
    else
        # we don't use assetserver, so we copy the asset to asset_folder
        # for someone else to serve them!
        if serializer.asset_folder === nothing
            error("Not using assetserver requires to set `asset_folder` to a valid local folder")
        end
        if !isdir(serializer.asset_folder)
            error("`asset_folder` doesn't exist: $(serializer.asset_folder)")
        end
        relative_path = relpath(path, serializer.asset_folder)
        if !(occursin("..", relative_path) || abspath(path) == relative_path)
            # file is already in asset folder
            return relative_path
        else
            path_base = dirname(path)
            file_name = basename(path)
            unique_file_name = unique_name_in_folder(serializer.asset_folder, file_name)
            unique_path = joinpath(serializer.asset_folder, unique_file_name)
            cp(path, unique_path, force=true)
            return unique_file_name
        end
    end
end
