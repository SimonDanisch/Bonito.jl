# Asset serving for a *proxied* session — one rendered in a worker process whose
# browser is reached by relaying through a host Bonito server (see
# `ProxyConnection`). Assets are the one part of the proxy that can't be pure
# relay: the browser fetches them over HTTP (`GET /assets/<key>`), not over the
# websocket, so the host must hold a `key => RemoteAsset` registry to answer the
# GET. That registry is the *only* server-side mirror of worker state — and it's
# refcounted, driven entirely by the worker.
#
# Ownership/refcount lives on the WORKER (it has the real session tree). The
# worker's `ProxyAssetServer` mirrors Bonito's own `HTTPAssetServer`/
# `ChildAssetServer` refcount scheme: a shared registry of `key => (refcount,
# asset)`, with each session (root + every `similar`-ed subsession) holding the
# keys it references. The host hears only the net transitions:
#   * 0→1 (first worker session to reference a key) → `proxy_asset_add(driver, …)`
#   * 1→0 (last release)                            → `proxy_asset_remove(driver, key)`
# The host applies those to one bridge `ChildAssetServer`, storing a `RemoteAsset`
# per key. `close` of that bridge child (host-session teardown / worker drop)
# drops everything at once — the safety net.

# Bytes the host must serve for an asset (read lazily so we only touch the file
# when shipping eagerly).
# B17: snapshot the bundle bytes under the per-asset lock so a concurrent
# `bundle!` can't tear the vector while we ship it to the host.
proxy_asset_bytes(asset::Asset) =
    isempty(asset.bundle_data) ? read(local_path(asset)) : bundle_data_snapshot(asset)
proxy_asset_bytes(asset::BinaryAsset) = asset.data

proxy_asset_mime(asset::Asset)       = string(file_mimetype(local_path(asset)))
proxy_asset_mime(asset::BinaryAsset) = asset.mime

proxy_asset_size(asset::Asset) =
    isempty(asset.bundle_data) ? Int(filesize(local_path(asset))) : length(asset.bundle_data)
proxy_asset_size(asset::BinaryAsset) = length(asset.data)

# Eager threshold: ship bytes inline (cached on the host) for small assets and
# the in-memory init bundle; leave big media to be fetched lazily on GET.
const PROXY_EAGER_MAX = 256 * 1024

# ── Worker side: refcounted asset server ────────────────────────────────────

# Shared registry across one proxied session tree's asset servers. Holds the
# refcount + the actual asset (so the worker can serve bytes on demand) and the
# host-bound add/remove sinks.
mutable struct ProxyAssetRegistry{D}
    driver::D            # transport: 0→1 fires `proxy_asset_add`, 1→0 `proxy_asset_remove`
    entries::Dict{String,Tuple{Int,AbstractAsset}}
    lock::ReentrantLock
end
ProxyAssetRegistry(driver) =
    ProxyAssetRegistry(driver, Dict{String,Tuple{Int,AbstractAsset}}(), ReentrantLock())

mutable struct ProxyAssetServer <: AbstractAssetServer
    registry::ProxyAssetRegistry
    keys::Set{String}     # keys THIS (sub)session holds a ref on
end
ProxyAssetServer(registry::ProxyAssetRegistry) = ProxyAssetServer(registry, Set{String}())
ProxyAssetServer(driver) = ProxyAssetServer(ProxyAssetRegistry(driver))

# Subsessions share the registry (so the refcount spans the whole tree) but get
# their own key set — exactly the HTTPAssetServer↔ChildAssetServer relationship.
Base.similar(s::ProxyAssetServer) = ProxyAssetServer(s.registry)

setup_asset_server(::ProxyAssetServer) = nothing

# Read a (0-based inclusive) byte range of a retained asset — the worker's answer
# to a host lazy fetch. `stop < 0` means "to the end".
function read_proxy_asset(reg::ProxyAssetRegistry, key::AbstractString, start::Integer=0, stop::Integer=-1)
    asset = lock(reg.lock) do
        e = get(reg.entries, key, nothing)
        e === nothing ? nothing : e[2]
    end
    asset === nothing && return UInt8[]
    bytes = proxy_asset_bytes(asset)
    stop < 0 && (stop = length(bytes) - 1)
    return bytes[(start+1):(stop+1)]
end

function url(server::ProxyAssetServer, asset::AbstractAsset)
    is_online(asset) && return online_path(asset)
    key = unique_file_key(asset)
    reg = server.registry
    # B39: `proxy_asset_add` is a Malt `remote_call` to the worker. Running it
    # under `reg.lock` pins every other lock taker (e.g. `close`) on a dead /
    # slow worker. Decide the 0→1 transition under the lock, then issue the
    # remote call after releasing it. The refcount bookkeeping (incl. claiming
    # `key in server.keys`) is committed under the lock so concurrent `url`
    # callers can't both fire the add.
    do_add = lock(reg.lock) do
        (key in server.keys) && return false
        entry = get(reg.entries, key, nothing)
        push!(server.keys, key)
        if entry === nothing
            reg.entries[key] = (1, asset)
            return true   # 0→1: we own the add
        else
            reg.entries[key] = (entry[1] + 1, entry[2])
            return false
        end
    end
    if do_add
        total = proxy_asset_size(asset)
        cached = total <= PROXY_EAGER_MAX ? proxy_asset_bytes(asset) : nothing
        proxy_asset_add(reg.driver, key, proxy_asset_mime(asset), total, cached)
    end
    suffix = (asset isa Asset && asset.es6module) ? "?" * asset.content_hash[] : ""
    return "/assets/" * key * suffix
end

# Releasing this (sub)session's refs; on 1→0 tell the host to drop the key.
function Base.close(server::ProxyAssetServer)
    reg = server.registry
    # B39: collect the 1→0 keys under the lock, then fire `proxy_asset_remove`
    # (a Malt remote_call) outside it, so a dead worker can't wedge the lock.
    to_remove = lock(reg.lock) do
        removed = String[]
        for key in server.keys
            entry = get(reg.entries, key, nothing)
            entry === nothing && continue
            if entry[1] <= 1
                delete!(reg.entries, key)
                push!(removed, key)
            else
                reg.entries[key] = (entry[1] - 1, entry[2])
            end
        end
        empty!(server.keys)
        return removed
    end
    for key in to_remove
        proxy_asset_remove(reg.driver, key)   # 1→0
    end
    return nothing
end

# ── Host side: RemoteAsset + the bridge registry ────────────────────────────

# What the host serves for a proxied key. `cached` bytes are served directly
# (eager / init bundle); otherwise `fetch(start, stop)` pulls the byte range from
# the worker (lazy — wired to a `Malt.remote_call` by the proxy driver). `total`
# is the full length (known from the worker at add time) for range math.
struct RemoteAsset{D} <: AbstractAsset
    key::String
    mime::String
    total::Int
    cached::Union{Nothing,Vector{UInt8}}
    driver::D            # host-side; `proxy_fetch(driver, key, start, stop)` pulls a byte range
end

mediatype(asset::RemoteAsset) = Symbol(HTTPServer.mimetype_to_extension(asset.mime))
is_online(::RemoteAsset) = false
unique_file_key(asset::RemoteAsset) = asset.key

# B39: a `proxy_fetch` to a dead/hung worker would otherwise pin the host HTTP
# task forever. Run it on a spawned task and give up after a bounded wait,
# returning a 504 instead of hanging. (The spawned task may still be parked on
# the dead worker, but the HTTP task is freed.)
const PROXY_FETCH_TIMEOUT = 30.0

function proxy_fetch_timed(driver, key, start, stop)
    t = Threads.@spawn proxy_fetch(driver, key, start, stop)
    if timedwait(() -> istaskdone(t), PROXY_FETCH_TIMEOUT; pollint=0.05) !== :ok
        return nothing
    end
    return fetch(t)::Vector{UInt8}
end

# Serve a RemoteAsset with range support, mirroring `serve_asset`: cached bytes
# are sliced locally; otherwise the range is fetched from the worker.
function serve_remote_asset(request, asset::RemoteAsset)
    headers = Pair{String,String}[
        "Access-Control-Allow-Origin" => "*",
        "Content-Type"  => asset.mime,
        "Cache-Control" => CACHE_CONTROL_MUTABLE,
        "Accept-Ranges" => "bytes",
    ]
    rng = parse_byte_range(HTTP.header(request, "Range", ""), asset.total)
    if rng === nothing
        if asset.cached === nothing
            body = proxy_fetch_timed(asset.driver, asset.key, 0, asset.total - 1)
            body === nothing && return HTTP.Response(504, "proxy asset fetch timed out")
        else
            body = asset.cached
        end
        return HTTP.Response(200, headers; body=body)
    end
    start, stop = rng
    if asset.cached === nothing
        body = proxy_fetch_timed(asset.driver, asset.key, start, stop)
        body === nothing && return HTTP.Response(504, "proxy asset fetch timed out")
    else
        body = asset.cached[(start+1):(stop+1)]
    end
    push!(headers, "Content-Range"  => "bytes $start-$stop/$(asset.total)")
    push!(headers, "Content-Length" => string(stop - start + 1))
    return HTTP.Response(206, headers; body=body)
end

# Register / release a proxied key on the host's bridge `ChildAssetServer`. Same
# refcount bookkeeping as `register!`/`close`, but the asset is a `RemoteAsset`
# and the (de)registration is driven by relayed worker events.
function register_proxy_asset!(child::ChildAssetServer, asset::RemoteAsset)
    parent = child.parent
    path = "/assets/" * asset.key
    lock(parent.lock) do
        path in child.files && return
        entry = get(parent.files, path, nothing)
        parent.files[path] = entry === nothing ?
            AssetEntry(1, asset) : AssetEntry(entry.refcount + 1, entry.asset)
        push!(child.files, path)
    end
    return
end

function release_proxy_asset!(child::ChildAssetServer, key::AbstractString)
    parent = child.parent
    path = "/assets/" * key
    lock(parent.lock) do
        path in child.files || return
        delete!(child.files, path)
        entry = get(parent.files, path, nothing)
        entry === nothing && return
        entry.refcount <= 1 ? delete!(parent.files, path) :
            (parent.files[path] = AssetEntry(entry.refcount - 1, entry.asset))
    end
    return
end
