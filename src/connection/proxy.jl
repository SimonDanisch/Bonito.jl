# Proxying a Bonito session rendered in ONE Julia process onto the page of a
# DIFFERENT Bonito server. The worker renders an `App` (its plots, widgets,
# observables live there); the host server owns the browser connection. We make
# the worker's session ride the host's existing socket instead of opening its own.
#
# Why it works with no new browser protocol: the browser keys every cached object
# in ONE global cache by id, and an `UpdateObservable` frame is just
# `{msg_type, id, payload}` — no session id. So worker→browser is a *raw byte
# relay* (host never decodes it), and browser→worker is a lookup by id. The only
# requirement is globally-unique ids, which `cache_key` guarantees by prefixing
# the worker session's observable ids (see serialization/caching.jl).
#
# Three flows, all over the host's one socket:
#   * init          worker renders a self-contained bundle (DOM fragment + a
#                   binary of init messages); host embeds the fragment and drives
#                   `Bonito.init_session(prefix, …)` via `on_document_load`.
#   * worker→browser  observable updates: raw relay through `on_send`.
#   * browser→worker  updates/lifecycle: host routes by id-prefix / session id
#                   (`route_to_remote`) and forwards the decoded frame to the
#                   worker, where the REAL observables live.
#
# `ProxyConnection`/`ProxyAssetServer` are transport-agnostic: the in-process
# `embed_app` wires the sinks with direct calls; a remote driver (BonitoTeam)
# wires them to a websocket. Either way the worker code is identical.

# ── Worker side: the connection ─────────────────────────────────────────────

mutable struct ProxyConnection <: FrontendConnection
    # Per-session namespace prepended to this session's observable ids so they
    # can't collide with the host's (or another worker's) ids in the browser's
    # one global cache. Equal to the worker session's id.
    prefix::String
    # Host-bound sink for outbound frames (worker → browser). Gets the final
    # serialized bytes; the host relays them onto the browser socket verbatim.
    on_send::Function          # (bytes::Vector{UInt8}) -> Nothing
    open::Threads.Atomic{Bool}
end

ProxyConnection(prefix::AbstractString, on_send::Function) =
    ProxyConnection(String(prefix), on_send, Threads.Atomic{Bool}(true))

# Default: normal sessions don't namespace. Only `ProxyConnection` carries a
# prefix — keeping `cache_key` byte-identical to the old behavior elsewhere.
id_prefix(::FrontendConnection) = ""
id_prefix(c::ProxyConnection) = c.prefix

# Subsession ids are the third browser-global namespace (after object cache keys
# and dom ids) the worker must prefix, so the host can route the subsession's
# lifecycle frames (`JSDoneLoading`/`CloseSession`/`GetSessionDOM`) by namespace
# without tracking the worker's session tree. Normal sessions get a bare uuid.
function proxied_session_id(parent::Session)
    prefix = id_prefix(connection(parent))
    return isempty(prefix) ? string(uuid4()) : string(prefix, "/", uuid4())
end

function Base.write(c::ProxyConnection, bytes::AbstractVector{UInt8})
    c.open[] && c.on_send(collect(bytes))
    return nothing
end
Base.isopen(c::ProxyConnection) = c.open[]
Base.close(c::ProxyConnection) = (c.open[] = false; nothing)

# The host owns the browser transport; a proxied session injects no connection
# JS of its own (that would try to open a second socket).
setup_connection(::Session{ProxyConnection}) = nothing

# ── Worker side: render an App into a proxied session ───────────────────────

# What the worker hands the host to embed an app: the rendered DOM fragment, the
# URL of the init-message bundle (already shipped to the host's asset server),
# and the namespace/compression the host needs to drive `init_session`.
struct ProxyRender
    session::Session
    html::String
    init_url::String
    prefix::String
    compression::Bool
end

"""
    render_proxied(app, prefix; compression, on_send, on_asset) -> ProxyRender

Render `app` into a fresh proxied root `Session` (id == `prefix`). Produces the
DOM fragment as HTML and ships the session's init messages as one binary via the
`ProxyAssetServer` (so the host serves it). No init `<script>` is inlined — the
host drives `init_session` itself (so it works even when the host mounts the
fragment via innerHTML, where inline scripts don't execute).

`on_send(bytes)` relays a frame to the browser; `asset_server` is a
`ProxyAssetServer` whose add/remove sinks the driver has wired to the host.
"""
function render_proxied(app::App, prefix::AbstractString;
                        compression::Bool, on_send::Function,
                        asset_server::ProxyAssetServer)
    conn = ProxyConnection(prefix, on_send)
    session = Session(conn;
                      id = String(prefix),
                      asset_server = asset_server,
                      compression_enabled = compression)
    # init=false: render DOM + styles but DON'T inline the init script.
    fragment = session_dom(session, app; init=false)
    html = sprint(io -> show(io, fragment))
    # Whatever the render queued (object registrations + on_document_load) is the
    # session's init bundle. Ship it as one binary the browser fetches & replays.
    msgs = get_messages!(session)
    init_url = url(session, BinaryAsset(session, msgs))
    return ProxyRender(session, html, init_url, String(prefix), compression)
end

# ── Host side: route inbound browser frames for proxied (worker) sessions ───

const REMOTE_ROUTES_KEY = :bonito_remote_routes

# One registered proxied session on the host. `to_worker` forwards a decoded
# browser control frame to the worker (in-process: straight into the worker's
# `process_message`). `forward_bytes`, when set, is preferred for remote
# drivers: it ships the raw browser bytes to the worker so the worker's own
# inbox path (decompress + unpack + dispatch) runs identically to how a
# direct-WS session would handle them — no re-encode round-trip, no separate
# `deliver`-shaped worker entry point.
struct RemoteSession
    id::String                  # worker session id == observable-id prefix
    to_worker::Function         # (data::AbstractDict) -> Nothing
    forward_bytes::Union{Nothing, Function}  # (bytes::Vector{UInt8}) -> Nothing
end

# Backward-compat: in-process driver (`embed_app`) only needs `to_worker`.
RemoteSession(id::AbstractString, to_worker) =
    RemoteSession(String(id), to_worker, nothing)

# Remote driver entry point: provide `forward_bytes` to ship raw bytes through.
RemoteSession(id::AbstractString; to_worker = _ -> nothing,
                                  forward_bytes = nothing) =
    RemoteSession(String(id), to_worker, forward_bytes)

function remote_routes(root::Session)
    return get!(() -> Dict{String,RemoteSession}(), metadata_dict(root), REMOTE_ROUTES_KEY)
end

function register_remote!(host::Session, rs::RemoteSession)
    root = root_session(host)
    lock(root.deletion_lock) do
        remote_routes(root)[rs.id] = rs
    end
    return rs
end

function unregister_remote!(host::Session, id::AbstractString)
    root = root_session(host)
    lock(root.deletion_lock) do
        routes = get(metadata_dict(root), REMOTE_ROUTES_KEY, nothing)
        routes === nothing || delete!(routes, id)
    end
    return nothing
end

# The id a frame routes on: object id for observable updates, session id for the
# session-lifecycle frames. `nothing` for frames that are always handled locally
# (PingPong, JS errors, …). `UpdateSession` is server→browser only, so it never
# appears inbound.
function remote_route_id(data::AbstractDict)
    typ = data["msg_type"]
    typ == UpdateObservable && return get(data, "id", nothing)
    (typ == JSDoneLoading || typ == CloseSession || typ == GetSessionDOM) &&
        return get(data, "session", nothing)
    return nothing
end

"""
    route_to_remote(session, data; bytes=nothing) -> Bool

If `data` belongs to a registered proxied (worker) session — recognised purely
by its id being the worker's namespace prefix (the worker's root session id) or
starting with `prefix/` (its observables, subsessions, dom nodes) — forward the
frame to that worker and return `true`. The server holds no mirror of the
worker's sessions/objects; this namespace match is the whole routing table.
Returns `false` for the server's own frames (whose ids never carry a worker
prefix), which then fall through to normal local handling.

When `bytes` is the original (still-compressed) browser frame AND the matched
`RemoteSession` has a `forward_bytes` callback, those raw bytes are forwarded
verbatim — the worker then runs decompress + unpack + dispatch on its own
inbox path, exactly as a direct-WS session would. Falls back to the `to_worker`
data callback for in-process drivers / pre-`forward_bytes` callers.
"""
function route_to_remote(session::Session, data::AbstractDict;
                         bytes::Union{Nothing, AbstractVector{UInt8}} = nothing)
    root = root_session(session)
    routes = get(metadata_dict(root), REMOTE_ROUTES_KEY, nothing)
    (routes === nothing || isempty(routes)) && return false
    id = remote_route_id(data)
    id isa AbstractString || return false
    for rs in values(routes)
        if id == rs.id || startswith(id, rs.id * "/")
            if bytes !== nothing && rs.forward_bytes !== nothing
                rs.forward_bytes(bytes)
            else
                rs.to_worker(data)
            end
            return true
        end
    end
    return false
end

# ── Host side: embed a worker app into a host session (in-process driver) ───

# A renderable wrapping a `ProxyRender`. Mounting it embeds the worker's DOM and
# schedules the worker session's `init_session` in the browser via
# `on_document_load` — which rides the SAME message bundle as the surrounding
# DOM, so it fires after the fragment mounts whether that's the initial page or a
# later subsession swap (`UpdateSession`), unlike an inline `<script>`.
struct RemoteApp
    render::ProxyRender
end

function jsrender(session::Session, app::RemoteApp)
    pr = app.render
    on_document_load(session, js"""
        Bonito.init_session($(pr.prefix), Bonito.fetch_binary($(pr.init_url)), "sub", $(pr.compression));
    """)
    return jsrender(session, DOM.div(DontEscape(pr.html); dataBonitoRemote=pr.prefix))
end

"""
    embed_app(host::Session, app::App) -> RemoteApp

Render `app` in its own proxied session and embed it into `host`'s page,
in-process: worker→browser frames relay onto the host socket, the worker's
assets register on the host asset server, and browser→worker frames route into
the worker session. The worker's observables stay live in this process, so the
embedded app is fully interactive. Tears down (drops the browser-side session,
closes the worker session, deregisters the route) when `host` closes.

This is the reference in-process driver; a remote driver swaps the three sinks
for a transport but renders the worker app the same way.
"""
function embed_app(host::Session, app::App)
    prefix = string(uuid4())
    on_send = bytes -> write(connection(host), bytes)
    # Worker asset events drive a bridge ChildAssetServer on the host (in-process:
    # the host's own asset server). Lazy fetches read straight from the worker
    # registry; a remote driver swaps that closure for a Malt remote_call.
    bridge = host.asset_server
    local registry::ProxyAssetRegistry
    on_add = (key, mime, total, cached) -> register_proxy_asset!(
        bridge, RemoteAsset(key, mime, total, cached,
                            (s, e) -> read_proxy_asset(registry, key, s, e)))
    on_remove = key -> release_proxy_asset!(bridge, key)
    asset_server = ProxyAssetServer(on_add, on_remove)
    registry = asset_server.registry
    pr = render_proxied(app, prefix;
                        compression = compression_enabled(host),
                        on_send = on_send, asset_server = asset_server)
    # Browser → worker: forward the decoded frame straight into the worker
    # session, where the real observables live (we're already on an @async
    # per-message task from the host's inbox reader).
    register_remote!(host, RemoteSession(prefix, data -> process_message(pr.session, data)))
    on(host.on_close) do _
        unregister_remote!(host, prefix)
        # Drop the worker session's objects from the browser's global cache.
        if isopen(host)
            try
                evaljs(host, js"Bonito.free_session($(prefix));")
            catch e
                @debug "embed_app: free_session on teardown failed" exception = e
            end
        end
        close(pr.session)
    end
    return RemoteApp(pr)
end
