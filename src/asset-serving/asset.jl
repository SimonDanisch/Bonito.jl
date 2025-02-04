
mediatype(asset::Asset) = asset.media_type

function get_path(asset::Asset)
    isempty(asset.online_path) ? asset.local_path : asset.online_path
end

hash_content(x) = bytes2hex(sha1(x))

function unique_file_key(path::String)
    return hash_content(abspath(path)) * "-" * Bonito.URIs.escapeuri(basename(path))
end
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

mediatype(asset::BinaryAsset) = Symbol(HTTPServer.mimetype_to_extension(asset.mime))

function unique_file_key(asset::Asset)
    file = local_path(asset)
    return unique_file_key(normpath(abspath(expanduser(file))))
end

function unique_file_key(asset::BinaryAsset)
    key = unique_file_key(string(hash(asset.data)))
    ext = mediatype(asset)
    return "$key.$ext"
end

url(session::Session, asset::AbstractAsset) = url(session.asset_server, asset)
function url(::Nothing, asset::Asset)
    # Allow to use nothing for specifying an online url
    @assert !isempty(asset.online_path)
    return asset.online_path
end

function render_asset(session::Session, asset_server, asset::Asset)
    @assert mediatype(asset) in (:css, :js, :mjs) "Found: $(mediatype(asset)))"
    ref = url(session, asset)
    if mediatype(asset) == :js
        if asset.es6module
            return DOM.script(src=ref; type="module")
        else
            return DOM.script(src=ref)
        end
    elseif mediatype(asset) == :css
        return DOM.link(href=ref, rel="stylesheet", type="text/css")
    end
end

function jsrender(session::Session, asset::Asset)
    if mediatype(asset) in (:jpeg, :jpg, :png)
        return DOM.img(src=url(session, asset))
    elseif mediatype(asset) in (:css, :js)
        # We include css/js assets with the above `render_asset` in session_dom
        # So that we only include any depency one time
        push!(session.imports, asset)
        return nothing
    else
        error("Unrecognized asset media type: $(mediatype(asset))")
    end
end

"""
    is_online(path)

Determine whether or not the specified path is a local filesystem path (and not
a remote resource that is hosted on, for example, a CDN).
"""
is_online(path::AbstractString) = any(startswith.(path, ("//", "https://", "http://", "ftp://")))
is_online(path::Path) = false # RelocatableFolders is only used for local filesystem paths
is_online(asset::Asset) = isempty(local_path(asset))
is_online(asset::BinaryAsset) = false
is_online(asset::Link) = true

online_path(asset::Link) = asset.target
online_path(asset::Asset) = asset.online_path
online_path(::BinaryAsset) = ""

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
julia> Bonito.getextension("foo.bar.js")
"js"
julia> Bonito.getextension("https://my-cdn.net/foo.bar.css?version=1")
"css"
```
Taken from WebIO.jl
"""
function getextension(path::AbstractString)
    sym = lowercase(last(split(first(split(path, "?")), ".")))
    sym == "mjs" && return "js"
    return sym
end
getextension(path::Path) = getextension(getroot(path))

function Base.show(io::IO, asset::Asset)
    print(io, get_path(asset))
end

function bundle_folder(bundle_dir, local_path, name, media_type)
    bundle_dir = if !isnothing(bundle_dir) && !isempty(bundle_dir)
        bundle_dir
    elseif isempty(local_path)
        get_deps_path(name)
    else
        dirname(local_path)
    end
    isdir(bundle_dir) || mkpath(bundle_dir)
    return joinpath(bundle_dir, string(name, ".bundled.", media_type))
end


function generate_bundle_file(file, bundle_file)
    if isfile(file) || is_online(file)
        if needs_bundling(file, bundle_file)
            bundled, err = deno_bundle(file, bundle_file)
            if !bundled
                if isfile(bundle_file)
                    @warn "Failed to bundle $file: $err"
                else
                    error("Failed to bundle $file: $err")
                end
            end
        end
        return bundle_file
    else
        return bundle_file
    end
end

function Asset(path_or_url::Union{String,Path}; name=nothing, es6module=false, check_isfile=false, bundle_dir::Union{Nothing,String,Path}=nothing, mediatype=Symbol(getextension(path_or_url)))
    local_path = ""; real_online_path = ""
    if is_online(path_or_url)
        local_path = ""
        real_online_path = path_or_url
    else
        local_path = normalize_path(path_or_url; check_isfile=check_isfile)
    end
     if es6module
        path = bundle_folder(bundle_dir, local_path, name, mediatype)
        # We may need to bundle immediately, since otherwise the dependencies for bunddling may be gone!
        source = is_online(path_or_url) ? real_online_path : local_path
        bundle_file = generate_bundle_file(source, path)
        if !isfile(bundle_file)
            error("Failed to bundle $source: $path. bundle_dir: $(bundle_dir)")
        end
        bundle_data = read(bundle_file) # read the into memory to make it relocatable
        content_hash = RefValue{String}(hash_content(bundle_data))
    else

        bundle_file = ""
        bundle_data = UInt8[]
        content_hash = RefValue{String}("")
    end
    return Asset(name, es6module, mediatype, real_online_path, local_path, bundle_file, bundle_data, content_hash)
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
    folder = abspath(first(Base.DEPOT_PATH), "Bonito")
    isdir(folder) || mkpath(folder)
    return joinpath(folder, name)
end

function bundle_path(asset::Asset)
    return asset.bundle_file
end

last_modified(path::Path) = last_modified(Bonito.getroot(path))
function last_modified(path::String)
    Dates.unix2datetime(Base.Filesystem.mtime(path))
end

function needs_bundling(path, bundled)
    is_online(path) && return !isfile(bundled)
    !isfile(bundled) && return true
    # If bundled happen after last modification of asset
    return last_modified(path) > last_modified(bundled)
end

function needs_bundling(asset::Asset)
    asset.es6module || return false
    path = get_path(asset)
    bundled = bundle_path(asset)
    return needs_bundling(path, bundled)
end



bundle!(asset::BinaryAsset) = nothing

function bundle!(asset::Asset)
    needs_bundling(asset) || return
    bundle_file = String(bundle_path(asset))
    source = String(get_path(asset))
    has_been_bundled, err = deno_bundle(source, bundle_file)
    if isfile(bundle_file)
        data = read(bundle_file)
        resize!(asset.bundle_data, length(data))
        copyto!(asset.bundle_data, data)
        asset.content_hash[] = hash_content(data)
        # when shipping, we don't have the correct time stamps, so we can't accurately say if we need bundling :(
        # So we need to rely on the package authors to bundle before creating a new release!
        return
    end
    # if bundle_data is stored in the asset, we dont necessarily need to bundle
    # But it's likely outdated - which is fine for e.g. relocatable packages
    if !has_been_bundled && isempty(asset.bundle_data)
        # Not bundling if bundling is needed is an error...
        # In theory it could be a warning, but this way we make CI fail, so that
        # PRs that forget to bundle JS dependencies will fail!
        error("Asset $(asset) needs bundling.
            If you've edited the asset, please load `Deno_jll` (e.g. `using Deno_jll, Bonito`),
            which is an optional dependency needed for Developing Bonito Assets.
            After that, assets should be bundled on precompile and whenever they're used after editing the asset.
            If you're just using a package, please open an issue with the Package maintainers,
            they must have forgotten bundling.
            Error: $err")
    end
    if !isempty(asset.bundle_data) && !has_been_bundled && isfile(source)
        @warn "Asset $(asset) being served from memory, but failed to bundle with error: $(err)."
    end
    return
end
