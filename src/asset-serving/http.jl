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
# Finalizer: schedules `close(self)` via `@async`. Required because a Session
# can become unreachable without ever being explicitly closed — at which
# point its `asset_server::ChildAssetServer` is also collectable, and this
# finalizer is the only thing that releases the refcount contributions on
# the parent. The internal Session→inbox→bound-task→closure→Session cycle
# does NOT keep a Session alive (Julia's GC collects unreachable cycles),
# so the orphan-without-close case is real. Examples: the DisplayHandler
# update path that replaces a not-yet-ready session and drops the old one;
# tests that construct Sessions without owning them past test scope; bare
# `ChildAssetServer` constructions in scratch code. Without this finalizer
# those entries leak until the parent server closes.
#
# Why `@async` and not direct `close`: the GC may run finalizers on a task
# currently in `wait()`, and `close` takes `parent.lock`. A slow-lock from
# that context either yields ("task switch not allowed from inside gc
# finalizer") or push!es the current task onto a second wait queue,
# corrupting the linked list ("val already in a list"). `@async` only
# `schedule`s — no Julia-level lock taken — so the actual lock-acquiring
# work runs on a fresh task, fully decoupled from the GC.
mutable struct ChildAssetServer <: AbstractAssetServer
    parent::HTTPAssetServer
    files::Set{String}
    function ChildAssetServer(parent::HTTPAssetServer)
        child = new(parent, Set{String}())
        finalizer(child) do c
            # `@async close(c)` would silently swallow any exception from
            # close — nobody waits on this task, so errors vanish (and the
            # cleanup wouldn't actually happen). Wrap explicitly: log on
            # failure, never propagate (the finalizer must complete cleanly
            # — it's running on whatever task the GC interrupted).
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
        entry = lock(() -> server.files[string(key)], server.lock)
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
    if asset !== nothing
        if asset isa BinaryAsset
            header = ["Access-Control-Allow-Origin" => "*",
                "Content-Type" => asset.mime,
                "Cache-Control" => cache_control_for(asset)]
            return HTTP.Response(200, header; body=asset.data)
        else
            data = nothing
            if !isempty(asset.bundle_data)
                data = asset.bundle_data
            else
                if isfile(local_path(asset))
                    data = read(local_path(asset))
                end
            end
            if !isnothing(data)
                header = ["Access-Control-Allow-Origin" => "*",
                    "Content-Type" => file_mimetype(local_path(asset)),
                    "Cache-Control" => cache_control_for(asset),
                ]
                return HTTP.Response(200, header, body = data)
            end
        end
    end

    return HTTP.Response(404)
end

setup_asset_server(::ChildAssetServer) = nothing
setup_asset_server(::HTTPAssetServer) = nothing
