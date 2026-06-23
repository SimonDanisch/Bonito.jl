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
#   * worker→browser  observable updates: raw relay through `proxy_send(driver, …)`.
#   * browser→worker  updates/lifecycle: host routes by id-prefix / session id
#                   (`route_to_remote`) and `proxy_forward`s the decoded frame to
#                   the worker, where the REAL observables live.
#
# `ProxyConnection`/`ProxyAssetServer`/`RemoteSession`/`RemoteAsset` are
# transport-agnostic: they carry a `driver` value and dispatch the proxy verbs
# (`proxy_send`/`proxy_forward`/`proxy_asset_add`/`proxy_asset_remove`/
# `proxy_fetch`). The in-process `embed_app` driver implements them as direct
# calls; a remote driver (BonitoTeam) implements them over a websocket. Either
# way the worker code is identical.

# ── Worker side: the connection ─────────────────────────────────────────────

# ── Proxy driver protocol ───────────────────────────────────────────────────
# A proxy "driver" is the transport-specific glue between a proxied worker
# session and the host that fronts the browser. Rather than store closures in the
# proxy types (JS-style `obj.on_send(x)` callbacks), each type carries a driver
# value and the transport overloads these verbs with multiple dispatch. The
# in-process `embed_app` driver wires them as direct calls; a remote driver
# (BonitoTeam) wires them to a websocket — the worker code is identical either way.
#
# Worker-side verbs (the proxied session lives here):
function proxy_send end          # (driver, bytes::Vector{UInt8})          -> Nothing      ship a frame to the browser
function proxy_asset_add end     # (driver, key, mime, total, cached)      -> Nothing      a proxied asset went 0→1
function proxy_asset_remove end  # (driver, key)                           -> Nothing      … and 1→0
# Host-side verbs (the browser socket lives here):
function proxy_forward end       # (driver, data::AbstractDict)            -> Nothing      relay a decoded browser frame to the worker
function proxy_fetch end         # (driver, key, start::Int, stop::Int)    -> Vector{UInt8} pull an asset byte range from the worker

mutable struct ProxyConnection{D} <: FrontendConnection
    # Per-session namespace prepended to this session's observable ids so they
    # can't collide with the host's (or another worker's) ids in the browser's
    # one global cache. Equal to the worker session's id.
    prefix::String
    # Transport driver. Outbound frames (worker → browser) go through
    # `proxy_send(driver, bytes)`; the driver relays them onto the browser socket.
    driver::D
    open::Threads.Atomic{Bool}
end

ProxyConnection(prefix::AbstractString, driver) =
    ProxyConnection(String(prefix), driver, Threads.Atomic{Bool}(true))

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
    c.open[] && proxy_send(c.driver, collect(bytes))
    return nothing
end
Base.isopen(c::ProxyConnection) = c.open[]
Base.close(c::ProxyConnection) = (c.open[] = false; nothing)

# The host owns the browser transport; a proxied session injects no connection
# JS of its own (that would try to open a second socket).
setup_connection(::Session{<:ProxyConnection}) = nothing

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
    render_proxied(app, prefix; compression, driver, asset_server) -> ProxyRender

Render `app` into a fresh proxied root `Session` (id == `prefix`). Produces the
DOM fragment as HTML and ships the session's init messages as one binary via the
`ProxyAssetServer` (so the host serves it). No init `<script>` is inlined — the
host drives `init_session` itself (so it works even when the host mounts the
fragment via innerHTML, where inline scripts don't execute).

`driver` is the transport: `proxy_send(driver, bytes)` relays a frame to the
browser. `asset_server` is a `ProxyAssetServer` built over the same `driver` (so
its 0→1 / 1→0 transitions dispatch `proxy_asset_add` / `proxy_asset_remove`).
"""
function render_proxied(app::App, prefix::AbstractString;
                        compression::Bool, driver, asset_server::ProxyAssetServer)
    conn = ProxyConnection(prefix, driver)
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

# One registered proxied session on the host, keyed by the worker's namespace
# prefix. Inbound browser frames for it are forwarded via `proxy_forward(driver,
# data)` — in-process: straight into the worker's `process_message`; remote: the
# decoded frame re-packed onto the worker's websocket, where its own inbox path
# (decompress + unpack + dispatch) runs identically to a direct-WS session.
struct RemoteSession{D}
    id::String          # worker session id == observable-id prefix
    driver::D           # host-side driver; inbound browser frames route through
                        # `proxy_forward(driver, data)` to where the real observables live
end
RemoteSession(id::AbstractString, driver) = RemoteSession(String(id), driver)

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
    route_to_remote(session, data) -> Bool

If `data` belongs to a registered proxied (worker) session — recognised purely
by its id being the worker's namespace prefix (the worker's root session id) or
starting with `prefix/` (its observables, subsessions, dom nodes) — forward the
decoded frame to that worker via `proxy_forward(driver, data)` and return `true`.
The server holds no mirror of the worker's sessions/objects; this namespace match
is the whole routing table. Returns `false` for the server's own frames (whose
ids never carry a worker prefix), which then fall through to normal local handling.
"""
function route_to_remote(session::Session, data::AbstractDict)
    root = root_session(session)
    id = remote_route_id(data)
    id isa AbstractString || return false
    # `register_remote!`/`unregister_remote!` mutate `remote_routes` under
    # `deletion_lock`; reading + iterating it unlocked races a Dict rehash.
    # Snapshot the matching driver under the lock, then forward outside
    # it (forwarding may be a network call we don't want to hold the lock for).
    target = lock(root.deletion_lock) do
        routes = get(metadata_dict(root), REMOTE_ROUTES_KEY, nothing)
        (routes === nothing || isempty(routes)) && return nothing
        for rs in values(routes)
            if id == rs.id || startswith(id, rs.id * "/")
                return rs.driver
            end
        end
        return nothing
    end
    target === nothing && return false
    proxy_forward(target, data)
    return true
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

This is the reference in-process driver (`InProcessProxy`); a remote driver
overloads the same proxy verbs over a transport but renders the app the same way.
"""
# The in-process driver: the host session both fronts the browser AND owns the
# worker session in this process, so every proxy verb is a direct call. (A remote
# driver — BonitoTeam — implements the same verbs over a websocket.) `registry`
# and `worker_session` are back-filled once `render_proxied` has built them.
mutable struct InProcessProxy
    host::Session
    registry::Union{Nothing,ProxyAssetRegistry}
    worker_session::Union{Nothing,Session}
end
InProcessProxy(host::Session) = InProcessProxy(host, nothing, nothing)

proxy_send(d::InProcessProxy, bytes) = (write(connection(d.host), bytes); nothing)
proxy_asset_add(d::InProcessProxy, key, mime, total, cached) =
    (register_proxy_asset!(d.host.asset_server, RemoteAsset(key, mime, total, cached, d)); nothing)
proxy_asset_remove(d::InProcessProxy, key) = (release_proxy_asset!(d.host.asset_server, key); nothing)
proxy_forward(d::InProcessProxy, data) = (process_message(d.worker_session, data); nothing)
proxy_fetch(d::InProcessProxy, key, start, stop) = read_proxy_asset(d.registry, key, start, stop)

function embed_app(host::Session, app::App)
    prefix = string(uuid4())
    driver = InProcessProxy(host)
    asset_server = ProxyAssetServer(driver)
    driver.registry = asset_server.registry          # proxy_fetch reads it
    pr = render_proxied(app, prefix; compression = compression_enabled(host),
                        driver = driver, asset_server = asset_server)
    driver.worker_session = pr.session                # proxy_forward routes browser→worker here
    register_remote!(host, RemoteSession(prefix, driver))
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
