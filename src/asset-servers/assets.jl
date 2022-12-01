
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
    last_bundled = Base.RefValue{Union{Nothing, Dates.DateTime}}(nothing)
    return Asset(name, es6module, mediatype, real_online_path, local_path, last_bundled)
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
        close(iob64_encode)
    end
end

function to_data_url(source::String, mime::String)
    return sprint() do io
        print(io, "data:$(mime);base64,")
        iob64_encode = Base64EncodePipe(io)
        print(iob64_encode, source)
        close(iob64_encode)
    end
end

"""
    dependency_path(paths...)

Path to serve downloaded dependencies
"""
dependency_path(paths...) = joinpath(@__DIR__, "..", "..", "js_dependencies", paths...)

const JSServeLib = ES6Module(dependency_path("JSServe.js"))
const Websocket = ES6Module(dependency_path("Websocket.js"))
const TailwindCSS = Asset(dependency_path("tailwind.min.css"))
const Styling = Asset(dependency_path("styling.css"))
const MarkdownCSS = Asset(dependency_path("markdown.css"))

include("mimetypes.jl")
include("no-server.jl")
include("http.jl")

function local_path(asset::Asset)
    if asset.es6module
        bundle!(asset)
        return bundle_path(asset)
    else
        return asset.local_path
    end
end

function get_deps_path(name)
    folder = abspath(first(Base.DEPOT_PATH), "jsserve")
    isdir(folder) || mkpath(folder)
    return joinpath(folder, name)
end

function bundle_path(asset::Asset)
    asset_path = if isempty(asset.local_path)
        get_deps_path(basename(asset.online_path))
    else
        asset.local_path
    end
    path, ext = splitext(asset_path)
    return string(path, ".bundled", ext)
end

last_modified(path::Path) = last_modified(JSServe.getroot(path))
function last_modified(path::String)
    Dates.unix2datetime(Base.Filesystem.mtime(path))
end

function needs_bundling(asset::Asset)
    asset.es6module || return false
    isnothing(asset.last_bundled[]) && return true
    path = asset.local_path
    isfile(bundle_path(asset)) || return true
    return last_modified(path) > asset.last_bundled[]
end

function bundle!(asset::Asset)
    needs_bundling(asset) || return
    path = get_path(asset)
    bundled = bundle_path(asset)
    Deno_jll.deno() do exe
        write(bundled, read(`$exe bundle $(path)`))
    end
    asset.last_bundled[] = Dates.now(UTC) # Filesystem.mtime(file) is in UTC
    return
end



const AVAILABLE_ASSET_SERVERS = Pair{DataType, Function}[]

"""
    register_asset_server!(condition::Function, ::Type{<: AbstractAssetServer})

Registers a new asset server type.
`condition` is a function that should return `nothing`, if the asset server type shouldn't be used, and an initialized asset server object, if the conditions are right.
E.g. The `JSServe.NoServer` be used inside an IJulia notebook so it's registered like this:
```julia
register_asset_server!(NoServer) do
    if isdefined(Main, :IJulia)
        return NoServer()
    end
    return nothing
end
```
The last asset server registered takes priority, so if you register a new connection last in your Package, and always return it,
You will overwrite the connection type for any other package.
If you want to force usage temporary, try:
```julia
force_asset_server(YourAssetServer()) do
    ...
end
# which is the same as:
force_asset_server!(YourAssetServer())
...
force_asset_server!()
```
"""
function register_asset_server!(condition::Function, ::Type{C}) where C <: AbstractAssetServer
    register_type!(condition, C, AVAILABLE_ASSET_SERVERS)
    return
end

const FORCED_ASSET_SERVER = Base.RefValue{Union{Nothing, AbstractAssetServer}}(nothing)

function force_asset_server!(conn::Union{Nothing, AbstractAssetServer}=nothing)
    force_type!(conn, FORCED_ASSET_SERVER)
end

function force_asset_server(f, conn::Union{Nothing, AbstractAssetServer})
    force_type(f, conn, FORCED_ASSET_SERVER)
end

# HTTPAssetServer is the fallback, so it's registered first (lower priority),
# and never returns nothing
register_asset_server!(HTTPAssetServer) do
    return HTTPAssetServer()
end

register_asset_server!(NoServer) do
    if isdefined(Main, :IJulia) || isdefined(Main, :PlutoRunner)
        return NoServer()
    else
        return  nothing
    end
end

function default_asset_server()
    return default_type(FORCED_ASSET_SERVER, AVAILABLE_ASSET_SERVERS)
end
