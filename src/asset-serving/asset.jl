
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
    if mediatype(asset) in (:jpeg, :jpg, :png, :svg, :gif)
        return jsrender(session, DOM.img(src=url(session, asset)))
    elseif mediatype(asset) in (:mp4, :webm, :ogg)
        vid = DOM.video(
            DOM.source(; src=url(session, asset), type="video/$(mediatype(asset))"), autoplay=true, controls=true
        )
        return jsrender(session, vid)
    elseif mediatype(asset) in (:css, :js)
        # We include css/js assets with the above `render_asset` in session_dom
        # So that we only include any depency one time
        push!(session.imports, asset)
        return nothing
    elseif mediatype(asset) == :html
        html = read(asset.local_path, String)
        return HTML{String}(html)
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
    # If it's an URL we assume it's bundled if the bundle file exists,
    # since the content of the url should not change (use versions in URLs!)
    isfile(bundle_file) && is_online(file) && return bundle_file
    if isfile(file) || is_online(file)
        if needs_bundling(file, bundle_file)
            bundled, err = deno_bundle(file, bundle_file)
            if !bundled
                if isfile(bundle_file)
                    @debug "Failed to bundle $file: $err"
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

    # For JS assets, default name to filename without extension (for global name inference)
    if isnothing(name)
        name = String(splitext(basename(path_or_url))[1])
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
        # Tell Julia's precompile system that the package's compile-cache
        # validity depends on these files. Without this, a downstream
        # package like BonitoTeam that does `const ChatLib =
        # ES6Module(...)` at module scope captures `bundle_data` into its
        # precompile image; subsequent edits to the .js source don't
        # invalidate the cache, and `using BonitoTeam` keeps serving the
        # stale bundle even though the file on disk has the new bytes.
        if !is_online(path_or_url) && !isempty(local_path)
            Base.include_dependency(String(local_path))
        end
        !isempty(bundle_file) && Base.include_dependency(String(bundle_file))
    else
        bundle_file = ""
        bundle_data = UInt8[]
        content_hash = RefValue{String}("")
    end
    # Non-module Assets read on demand from `local_path` at serve time, so
    # they don't snapshot bytes into the precompile image — no
    # include_dependency needed for those. (The HTTP handler in
    # asset-serving/http.jl does `read(local_path(asset))` on each request.)
    return Asset(name, es6module, mediatype, real_online_path, local_path, bundle_file, bundle_data, content_hash, ReentrantLock())
end


"""
    ES6Module(path)

Create an ES6 module asset that will be bundled using Deno.

ES6 modules are automatically bundled with their dependencies when first loaded.
Interpolating an ES6Module in JavaScript code returns a `Promise` that resolves
to the module's exports.

## Example

```julia
THREE = ES6Module("https://unpkg.com/three@0.136.0/build/three.js")

js\"\"\"
\$(THREE).then(module => {
    // Use the module
    const scene = new module.Scene();
})
\"\"\"
```

## Rebundling

Bundling is automatic. Bonito writes a `<name>.bundled.js` next to the source and
regenerates it whenever the bundle is missing or older than the *main* module file
(see [`needs_bundling`](@ref)). With Deno + esbuild loaded and a writable source,
it re-bundles from source; if a fresh bundle can't be produced (read-only
filesystem, missing source, Deno/esbuild not loaded, or a `deno bundle` error) it
serves the cached/shipped bundle instead of crashing (see [`bundle_inner!`](@ref)).

The mtime check only watches the main module file, so editing an **imported** file
(e.g. `Session.js` imported by `Bonito.js`) won't trigger a rebundle. Force one by
deleting the bundle — it's regenerated on next use:

```julia
mod = ES6Module("path/to/module.js")
rm(String(mod.bundle_file))   # Bonito rebundles on next use
```

or, when you can't touch the filesystem, [`rebundle!`](@ref)`(mod)`.
"""
function ES6Module(path)
    name = String(splitext(basename(path))[1])
    asset = Asset(path; name=name, es6module=true)
    return asset
end

"""
    rebundle!(asset::Asset)

Programmatically drop `asset`'s cached bundle so the next request re-bundles
from source. **You rarely need to call this:** bundling is automatic.

For an `ES6Module(...)`, Bonito writes a `<name>.bundled.js` next to the source
and serves it. On every request it re-bundles when the bundle is **missing** or
**older than the source** (see `needs_bundling`). So the normal dev loop
is just:

- **Edit the `.js` source** → the bundle's mtime is now stale → it re-bundles on
  the next page load. Nothing else to do.
- **Delete the `<name>.bundled.js` file** (e.g. in `js_dependencies/`) → it is
  regenerated from source on the next load. This is the simplest way to force a
  fresh bundle, e.g. after pulling changes or when a bundle looks corrupt.

`rebundle!` does the same thing in code — it removes the on-disk bundle
(`asset.bundle_file`) and the in-memory cached bytes (`asset.bundle_data`) under
the asset's bundle lock — for the case where you can't (or don't want to) touch
the filesystem, e.g. invalidating a bundle from a running session:

```julia
const ChartLib = Bonito.ES6Module("chart.js")
# … programmatically regenerate without editing/deleting files …
Bonito.rebundle!(ChartLib)   # next page reload picks up the new source
```

No-op for non-ES6 assets (they have no bundle to drop).
"""
function rebundle!(asset::Asset)
    asset.es6module || return asset
    # Guard the in-memory drop with the same per-asset lock `bundle!` uses, so
    # a concurrent serve never sees a half-emptied vector.
    lock(asset.bundle_lock) do
        isempty(String(asset.bundle_file)) || rm(String(asset.bundle_file); force = true)
        empty!(asset.bundle_data)
    end
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

last_modified(path::Path) = last_modified(getroot(path))
function last_modified(path::String)
    Dates.unix2datetime(Base.Filesystem.mtime(path))
end

# Can we actually write to `path`? `filemode(path) & S_IWUSR` lies on read-only
# filesystems (squashfs/DMG app bundles preserve the writable mode bits from
# build time), so probe by opening for append — EROFS/EACCES surface here
# without touching the file's content or mtime.
function file_writeable(path::String)
    try
        open(identity, path, "a")
        return true
    catch e
        e isa Union{SystemError, Base.IOError} || rethrow()
        return false
    end
end

"""
    needs_bundling(path, bundled) -> Bool
    needs_bundling(asset::Asset) -> Bool

Whether the bundle at `bundled` must be (re)generated from the source at `path`.
True when the bundle is **missing**, or when it exists, is **writable**, and is
**older than the source**. A non-es6 asset never needs bundling.

A bundle we can't rewrite is treated as a trusted shipped bundle (see the
read-only note below), so it never reports stale — that case is served as-is
rather than looping on a re-bundle that can't be written. [`bundle_inner!`](@ref)
does the actual (re)bundle, falling back to the cached bytes when it can't.
"""
function needs_bundling(path, bundled)
    is_online(path) && return !isfile(bundled)
    !isfile(bundled) && return true
    # A bundle we cannot rewrite is a SHIPPED bundle (read-only package dir,
    # squashfs/DMG app bundle). Its mtime is whatever the packaging step left
    # behind — often older than the equally-repackaged source file — so the
    # mtime comparison below would demand a re-bundle that can never be
    # written (each render then burns the full deno timeout). Trust it.
    file_writeable(String(bundled)) || return false
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

"""
    bundle_data_snapshot(asset::Asset) -> Vector{UInt8}

Return a copy of the asset's current bundle bytes taken under the per-asset
bundle lock, so a concurrent `bundle!` can't tear the vector out from under a
serving HTTP task. Callers serve the returned copy.
"""
function bundle_data_snapshot(asset::Asset)
    return lock(asset.bundle_lock) do
        copy(asset.bundle_data)
    end
end

"""
    bundle!(asset::Asset)

(Re)bundle `asset` if [`needs_bundling`](@ref) says so, serialized per asset via
its `bundle_lock`. Cheap and idempotent: a no-op when the on-disk bundle is
already current, so it's safe to call on every render (it is — see
`print_js_code` and `local_path`). The actual work — and the fall-back-to-cache
behaviour when a fresh bundle can't be produced — lives in [`bundle_inner!`](@ref).
"""
function bundle!(asset::Asset)
    needs_bundling(asset) || return
    lock(asset.bundle_lock) do
        # Re-check inside the lock: another task may have just bundled while we
        # waited, so we don't redundantly re-run deno or re-tear the vector.
        needs_bundling(asset) || return
        bundle_inner!(asset)
    end
    return
end

"""
    bundle_inner!(asset::Asset)

(Re)generate `asset`'s on-disk `*.bundled.js` and mirror it into the cached
`asset.bundle_data`. Called under the asset's `bundle_lock` from [`bundle!`], only
when [`needs_bundling`](@ref) said a (re)bundle is due.

When Deno + esbuild are loaded and the source is present on a writable filesystem,
the bundle is regenerated from source and the fresh bytes are served — so a
removed `*.bundled.js` reliably re-bundles.

When a fresh bundle *can't* be produced — read-only filesystem, missing/unreachable
source, `Deno_jll`/`esbuild_jll` not loaded, or a `deno bundle` error — we serve
the cached `bundle_data` (the snapshot taken at [`Asset`](@ref) construction, or
the last successful bundle) rather than crash the app: **a stale bundle beats a
dead page.** We only raise when there is genuinely *nothing* to serve — no bundle
on disk *and* an empty `bundle_data` — which is what makes CI fail on a package
that forgot to ship a bundle.
"""
function bundle_inner!(asset::Asset)
    bundle_file = String(bundle_path(asset))
    source = String(get_path(asset))
    has_been_bundled, err = deno_bundle(source, bundle_file)
    if has_been_bundled || isfile(bundle_file)
        # A bundle exists on disk: either the fresh one deno just wrote
        # (`has_been_bundled`), or a pre-existing/shipped one we keep (best effort)
        # when re-bundling failed. Mirror it into memory so HTTP serving and
        # relocation use the same bytes.
        data = read(bundle_file)
        resize!(asset.bundle_data, length(data))
        copyto!(asset.bundle_data, data)
        asset.content_hash[] = hash_content(data)
        return
    end
    # No bundle on disk and deno produced none.
    if isempty(asset.bundle_data)
        # Nothing on disk, nothing cached, and we can't bundle -> fail loudly so a
        # forgotten/broken bundle surfaces (e.g. CI) instead of serving an empty
        # asset.
        error("Asset $(asset) needs bundling, but no bundle could be produced and \
            nothing is cached.
            If you've edited the asset, make sure `Deno_jll` and `esbuild_jll` load
            on this platform (optional dependencies that back `deno bundle`, only
            needed for developing Bonito assets).
            If you're just using a package, please open an issue with its
            maintainers — they likely forgot to ship a bundle.
            Error: $err")
    end
    # We have a cached bundle from a previous build / construction: serve it rather
    # than crash. Covers a read-only filesystem, a missing/unreachable source,
    # Deno/esbuild not loaded, or a `deno bundle` failure.
    @warn "Asset $(asset) served from its cached bundle; could not (re)bundle from source: $err"
    return
end
