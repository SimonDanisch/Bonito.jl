using .HTTPServer: has_route, get_route, route!

# Per-asset registry on the parent server. `refcount` is the number of live
# `ChildAssetServer`s that have registered this path; `asset` is the actual
# data being served. When refcount drops to zero (last child closed) the
# entry is removed and the bytes become collectible.
struct AssetEntry
    refcount::Int
    asset::AbstractAsset
end

mutable struct HTTPAssetServer <: AbstractAssetServer
    # Single source of truth: every served asset, keyed by its content URL.
    # Refcount is incremented by `register!(child, asset)` and decremented by
    # `close(child)`. Mutated only under `lock`.
    files::Dict{String, AssetEntry}
    server::Server
    lock::ReentrantLock
end

# A handle owned by a single `Session`. Holds the set of paths IT registered,
# so close is O(this child's files) — not O(all files in the parent) like the
# old design that scanned every entry's objectid set.
#
# Finalizer (safety net): defers `close(self)` to a fresh task via `@async`.
# The expected lifecycle is explicit close via `Session.close` /
# `close_subsession` (Observable swap, DisplayHandler swap-out, root
# tear-down). The finalizer covers paths that bypass those — `with_export`
# creating ephemeral sessions, test code dropping references, App-replace
# scenarios where the buffer turnover misses one. Without it those entries
# leak their refcount contributions on the parent until the parent server
# itself dies.
#
# Why `@async`: the GC may run finalizers on a task currently in `wait()`,
# and `close` takes `parent.lock`. A slow-lock from that context either
# yields ("task switch not allowed from inside gc finalizer") or pushes
# the current task onto a second wait queue, corrupting the linked list
# ("val already in a list"). `@async` only `schedule`s — no Julia-level
# lock taken — so the lock-acquiring close runs on a fresh task. Wrap the
# close in try/catch so a failure logs (nobody waits on the task).
mutable struct ChildAssetServer <: AbstractAssetServer
    parent::HTTPAssetServer
    files::Set{String}
    function ChildAssetServer(parent::HTTPAssetServer)
        child = new(parent, Set{String}())
        finalizer(child) do c
            @async try
                close(c)
            catch e
                @warn "ChildAssetServer finalizer close failed" exception=(e, catch_backtrace())
            end
            nothing
        end
        return child
    end
end

const MATCH_HEX = r"[\da-f]"
const ASSET_ROUTE_REGEX = r"assets-(?:\d+){20}"
const UNIQUE_FILE_KEY_REGEX = MATCH_HEX^40 * r"-.*"
const ASSET_URL_REGEX =
    "/" * ASSET_ROUTE_REGEX * "/" * UNIQUE_FILE_KEY_REGEX * r"(/?(?:\d+){20})?"
const HTTP_ASSET_ROUTE_KEY = "/assets/" * UNIQUE_FILE_KEY_REGEX

HTTPAssetServer() = HTTPAssetServer(get_server())

function HTTPAssetServer(server::Server)
    # We only have one HTTPAssetServer per Server,
    # And always just hand out ChildAssetServer to the session.
    # It's a bit of an abuse of the constructor,
    # but the API for Session is to just call the constructor of the desired assset server
    key = HTTP_ASSET_ROUTE_KEY
    lock(server.routes.lock) do
        if has_route(server.routes, key)
            return ChildAssetServer(get_route(server.routes, key))
        else
            http = HTTPAssetServer(Dict{String,AssetEntry}(), server, ReentrantLock())
            route!(server, HTTP_ASSET_ROUTE_KEY => http)
            return ChildAssetServer(http)
        end
    end
end

Base.similar(s::HTTPAssetServer) = ChildAssetServer(s)
Base.similar(s::ChildAssetServer) = ChildAssetServer(s.parent)

function Base.close(server::HTTPAssetServer)
    @debug "Closing HTTPAssetServer"
    HTTPServer.delete_route!(server.server, HTTP_ASSET_ROUTE_KEY)
    lock(server.lock) do
        empty!(server.files)
    end
end

# Release this child's claim on every path it registered. Each path's refcount
# drops by 1; when a refcount hits 0 (last holder gone) the entry is dropped.
# Idempotent: a second close is a no-op (the child's own `files` set is empty).
function Base.close(server::ChildAssetServer)
    parent = server.parent
    lock(parent.lock) do
        for path in server.files
            entry = get(parent.files, path, nothing)
            entry === nothing && continue
            if entry.refcount <= 1
                delete!(parent.files, path)
            else
                parent.files[path] = AssetEntry(entry.refcount - 1, entry.asset)
            end
        end
        empty!(server.files)
    end
end

# Caller must hold `parent.lock`. Registers `asset` under its content key
# (incrementing refcount if it already exists), records the path on `child`,
# and returns the URL the browser should fetch.
function register!(parent::HTTPAssetServer, child::ChildAssetServer, asset::AbstractAsset)
    path = "/assets/" * unique_file_key(asset)
    if path in child.files
        # This child already holds a ref — don't double-count.
        entry = parent.files[path]
        return entry, path
    end
    entry = get(parent.files, path, nothing)
    entry = entry === nothing ?
        AssetEntry(1, asset) :
        AssetEntry(entry.refcount + 1, entry.asset)
    parent.files[path] = entry
    push!(child.files, path)
    return entry, path
end

function url(server::HTTPAssetServer, asset::AbstractAsset)
    is_online(asset) && return online_path(asset)
    # Bare HTTPAssetServer (no child) — register a single ref under a synthetic
    # holder by inserting directly. Used by code paths that talk to the parent
    # without owning a child handle (e.g. `js_to_local_url`).
    lock(server.lock) do
        path = "/assets/" * unique_file_key(asset)
        if !haskey(server.files, path)
            server.files[path] = AssetEntry(1, asset)
        end
        suffix = (asset isa Asset && asset.es6module) ?
            "?" * asset.content_hash[] : ""
        return HTTPServer.relative_url(server.server, path * suffix)
    end
end

function url(child::ChildAssetServer, asset::AbstractAsset)
    is_online(asset) && return online_path(asset)
    parent = child.parent
    lock(parent.lock) do
        _, path = register!(parent, child, asset)
        suffix = (asset isa Asset && asset.es6module) ?
            "?" * asset.content_hash[] : ""
        return HTTPServer.relative_url(parent.server, path * suffix)
    end
end

function js_to_local_url(server::HTTPAssetServer, url::AbstractString)
    m = match(ASSET_URL_REGEX, url)
    if isnothing(m) || isempty(m)
        return url
    else
        key = URIs.URI(m[1]).path
        # B38: the asset may no longer be registered (a child closed and dropped
        # its refcount) while we're formatting a JS stack trace — a bare
        # `server.files[key]` would KeyError and kill the whole error-reporting
        # path. Fall back to the original url when the entry is gone.
        entry = lock(() -> get(server.files, string(key), nothing), server.lock)
        entry === nothing && return url
        return local_path(entry.asset) * ":" * m[2]
    end
end

function js_to_local_stacktrace(server::HTTPAssetServer, line::AbstractString)
    function to_url(matched_url)
        js_to_local_url(server, matched_url)
    end
    return replace(line, ASSET_URL_REGEX => to_url)
end

# Cache-Control profiles for the two asset shapes we serve. The URLs we
# emit are content-keyed in different ways, which determines whether
# `immutable` is safe:
#
#   * BinaryAsset            → URL key is hash(asset.data); URL changes
#                              whenever bytes change. Safe to mark
#                              immutable.
#   * Asset with es6module=true → URL has a `?<content_hash>` query suffix
#                              from `asset.content_hash`. Same property.
#                              Safe to mark immutable.
#   * Plain Asset            → URL key is hash(abspath(local_path)) only.
#                              The path is stable; the file's bytes are
#                              not. Marking immutable would freeze a
#                              stale copy in browser caches across
#                              deploys. Use a moderate max-age so deploys
#                              propagate within a day.
const CACHE_CONTROL_IMMUTABLE = "public, max-age=31536000, immutable"
const CACHE_CONTROL_MUTABLE   = "public, max-age=86400, must-revalidate"

@inline cache_control_for(asset::BinaryAsset) = CACHE_CONTROL_IMMUTABLE
@inline cache_control_for(asset::Asset)       =
    asset.es6module ? CACHE_CONTROL_IMMUTABLE : CACHE_CONTROL_MUTABLE

# Parse a single `Range: bytes=start-end` header against a known total size.
# Returns 0-based inclusive `(start, stop)` clamped to the resource, or
# `nothing` when there's no satisfiable range (caller serves the full 200).
# Handles the open-ended (`bytes=500-`) and suffix (`bytes=-500`) forms.
function parse_byte_range(range_header::AbstractString, total::Integer)
    m = match(r"^bytes=(\d*)-(\d*)$", strip(range_header))
    m === nothing && return nothing
    s_str, e_str = m.captures[1], m.captures[2]
    if isempty(s_str)
        isempty(e_str) && return nothing          # "bytes=-" is invalid
        n = parse(Int, e_str)
        n <= 0 && return nothing
        start = max(0, Int(total) - n)
        stop  = Int(total) - 1
    else
        start = parse(Int, s_str)
        stop  = isempty(e_str) ? Int(total) - 1 : min(parse(Int, e_str), Int(total) - 1)
    end
    (total == 0 || start > stop || start >= total) && return nothing
    return (start, stop)
end

# Serve a resource with HTTP Range support. Exactly one of `data` (in-memory
# bytes) / `file` (path on disk, read lazily so large media isn't slurped
# whole) is non-nothing. Browsers require `206 Partial Content` + `Content-Range`
# to play and seek `<video>`/`<audio>`; `Accept-Ranges: bytes` advertises it on
# the full 200 too.
# RFC 1123 date string for HTTP `Last-Modified`/`If-Modified-Since`.
function http_date(t::Real)
    return Dates.format(Dates.unix2datetime(t), Dates.RFC1123Format) * " GMT"
end

function serve_asset(request, data::Union{Vector{UInt8},Nothing},
                     file::Union{String,Nothing}, content_type, cache_control)
    total = data === nothing ? Int(filesize(file)) : length(data)
    headers = Pair{String,String}[
        "Access-Control-Allow-Origin" => "*",
        "Content-Type"  => content_type,
        "Cache-Control" => cache_control,
        "Accept-Ranges" => "bytes",
    ]
    # B38: plain (mutable) assets are marked `must-revalidate` but never emitted
    # a validator, so browsers couldn't actually revalidate and served stale
    # CSS/JS for the full max-age after an edit. For file-backed assets, emit
    # `Last-Modified` and honor `If-Modified-Since` with a 304. Content-keyed
    # assets (BinaryAsset / es6module) are immutable and don't need this.
    if file !== nothing
        mtime = Base.Filesystem.mtime(file)
        if mtime > 0
            last_modified = http_date(mtime)
            push!(headers, "Last-Modified" => last_modified)
            ims = HTTP.header(request, "If-Modified-Since", "")
            if !isempty(ims) && ims == last_modified
                return HTTP.Response(304, headers)
            end
        end
    end
    rng = parse_byte_range(HTTP.header(request, "Range", ""), total)
    if rng === nothing
        body = data === nothing ? read(file) : data
        return HTTP.Response(200, headers; body=body)
    end
    start, stop = rng
    len = stop - start + 1
    body = data === nothing ?
        open(io -> (seek(io, start); read(io, len)), file) :
        data[start+1:stop+1]
    push!(headers, "Content-Range" => "bytes $start-$stop/$total")
    push!(headers, "Content-Length" => string(len))
    return HTTP.Response(206, headers; body=body)
end

function (server::HTTPAssetServer)(context)
    path = URIs.URI(context.request.target).path
    # Hold server.lock around the Dict access — `close(::ChildAssetServer)`
    # mutates `files` (delete!) under the same lock; without this guard, a
    # concurrent close can corrupt the Dict mid-fetch (or delete the entry
    # between our haskey and getindex). See test/race_conditions_audit.jl F4.
    asset = lock(server.lock) do
        entry = get(server.files, path, nothing)
        entry === nothing ? nothing : entry.asset
    end
    asset === nothing && return HTTP.Response(404)
    if asset isa RemoteAsset
        # A proxied (worker) asset: serve cached bytes or fetch the range from
        # the worker. Defined in asset-serving/proxy.jl.
        return serve_remote_asset(context.request, asset)
    elseif asset isa BinaryAsset
        return serve_asset(context.request, asset.data, nothing,
                           asset.mime, cache_control_for(asset))
    elseif !isempty(asset.bundle_data)
        # B17: serve a snapshot taken under the per-asset bundle lock, so a
        # concurrent `bundle!`/`rebundle!` can't tear the vector mid-response.
        return serve_asset(context.request, bundle_data_snapshot(asset), nothing,
                           file_mimetype(local_path(asset)), cache_control_for(asset))
    elseif isfile(local_path(asset))
        return serve_asset(context.request, nothing, local_path(asset),
                           file_mimetype(local_path(asset)), cache_control_for(asset))
    end
    return HTTP.Response(404)
end

setup_asset_server(::ChildAssetServer) = nothing
setup_asset_server(::HTTPAssetServer) = nothing
