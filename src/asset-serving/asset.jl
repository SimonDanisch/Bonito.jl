
mediatype(asset::Asset) = asset.media_type

function get_path(asset::Asset)
    isempty(asset.online_path) ? asset.local_path : asset.online_path
end

unique_file_key(path::String) = bytes2hex(sha1(abspath(path))) * "-" * basename(path)
unique_file_key(path) = unique_file_key(string(path))
function unique_key(asset::Asset)
    if isempty(asset.online_path)
        path = asset.local_path
        # Hide file structure from users
        return unique_file_key(normpath(abspath(expanduser(path))))
    else
        return asset.online_path
    end
end

function unique_file_key(asset::BinaryAsset)
    key = unique_file_key(string(hash(asset.data)))
    ext = HTTPServer.mimetype_to_extension(asset.mime)
    return "$key.$ext"
end

url(session::Session, asset::Union{BinaryAsset, Asset}) = url(session.asset_server, asset)
function url(::Nothing, asset::Asset)
    # Allow to use nothing for specifying an online url
    @assert !isempty(asset.online_path)
    return asset.online_path
end

function jsrender(session::Session, asset::Asset)
    ref = url(session, asset)
    element = if mediatype(asset) == :js
        if asset.es6module
            return DOM.script(src=ref; type="module")
        else
            # TODO create sane import scheme in session.jl
            require_off = DOM.script("""
                window.__define = window.define;
                window.__require = window.require;
                window.define = undefined;
                window.require = undefined;
            """)
            require_on = DOM.script("""
                window.define = window.__define;
                window.require = window.__require;
                window.__define = undefined;
                window.__require = undefined;
            """)
            return DOM.div(require_off, DOM.script(src=ref), require_on)
        end
    elseif mediatype(asset) == :css
        return DOM.link(href=ref, rel="stylesheet", type="text/css")
    elseif mediatype(asset) in (:jpeg, :jpg, :png)
        return DOM.img(src=ref)
    else
        error("Unrecognized asset media type: $(mediatype(asset))")
    end
    return element
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

function Asset(path_or_url::Union{String, Path}; name=nothing, es6module=false, check_isfile=false, bundle_dir::Union{Nothing, String, Path}=nothing)
    local_path = ""; real_online_path = ""
    if is_online(path_or_url)
        local_path = ""
        real_online_path = path_or_url
    else
        local_path = normalize_path(path_or_url; check_isfile=check_isfile)

    end
    _bundle_dir = isnothing(bundle_dir) ? dirname(local_path) : bundle_dir
    mediatype = Symbol(getextension(path_or_url))
    return Asset(name, es6module, mediatype, real_online_path, local_path, _bundle_dir)
end

function ES6Module(path)
    name = String(splitext(basename(path))[1])
    asset = Asset(path; name=name, es6module=true)
    return asset
end

function CDNSource(name; user=nothing, version=nothing)
    url = "https://esm.sh/"
    if !isnothing(user)
        url = url * user * "/"
    end
    url = url * name
    if !isnothing(version)
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

function to_data_url(binary::Vector{UInt8}, mime="application/octet-stream")
    return sprint() do io
        print(io, "data:$(mime);base64,")
        iob64_encode = Base64EncodePipe(io)
        write(iob64_encode, binary)
        close(iob64_encode)
    end
end

function local_path(asset::Asset)
    if asset.es6module
        bundle!(asset)
        return bundle_path(asset)
    else
        return asset.local_path
    end
end

function get_deps_path(name)
    folder = abspath(first(Base.DEPOT_PATH), "JSServe")
    isdir(folder) || mkpath(folder)
    return joinpath(folder, name)
end

function bundle_path(asset::Asset)
    @assert !isempty(asset.name) "Asset has no name, which may happen if Asset constructor was called wrongly"
    bundle_dir = if !isempty(asset.bundle_dir)
        asset.bundle_dir
    elseif isempty(asset.local_path)
        get_deps_path(asset.name)
    else
        dirname(asset.local_path)
    end
    isdir(bundle_dir) || mkpath(bundle_dir)
    return joinpath(bundle_dir, string(asset.name, ".bundled.", asset.media_type))
end

last_modified(path::Path) = last_modified(JSServe.getroot(path))
function last_modified(path::String)
    Dates.unix2datetime(Base.Filesystem.mtime(path))
end

function needs_bundling(asset::Asset)
    asset.es6module || return false
    path = get_path(asset)
    bundled = bundle_path(asset)
    !isfile(bundled) && return true
    # If bundled happen after last modification of asset
    return last_modified(path) > last_modified(bundled)
end

bundle!(asset::BinaryAsset) = nothing

function bundle!(asset::Asset)
    needs_bundling(asset) || return
    has_been_bundled = deno_bundle(get_path(asset), bundle_path(asset))
    if !has_been_bundled
        # Not bundling if bundling is needed is an error...
        # In theory it could be a warning, but this way we make CI fail, so that
        # PRs that forget to bundle JS dependencies will fail!
        error("Asset $(asset) needs bundling.
            If you've edited the asset, please load `Deno_jll` (e.g. `using Deno_jll, JSServe`),
            which is an optional dependency needed for Developing JSServe Assets.
            After that, assets should be bundled on precompile and whenever they're used after editing the asset.
            If you're just using a package, please open an issue with the Package maintainers,
            they must have forgotten bundling.")
    end
    return
end
