# Bonito architecture

How Bonito actually works, file by file — the mental model needed before
changing session, protocol, serialization, or proxy code. Style/API
conventions live in [AGENTS.md](AGENTS.md); this is mechanism. Line references
drift; function names are the stable anchors.

## 0. The one invariant everything hangs on

An `App` renders into a `Session`; the session serializes objects ONCE and
after that ships only references; the frontend mirrors the session's state.
This is only sound because a session tree has exactly ONE frontend, reached
over ONE ordered connection: **"serialized" implies "delivered to the owning
page, in order"**. Every subsystem below leans on that: the object cache sends
`TrackingOnly` refs for anything already cached; plots reference glyphs shipped
earlier; the init bundle assumes queued messages replay before later sends.
When you build anything where fragments mount independently (proxied workers,
lazily-mounted chat results), you must either preserve this invariant
(serialize-on-mount, per-page cache scope) or make every payload
self-contained/pullable. Breaking it silently is how "sometimes the plot never
loads" bugs are born.

## 1. Session model — `types.jl`, `session.jl`

- `RootSession{Connection}` holds the per-tree shared state: the connection,
  the `inbox::Channel` (inbound frames), `deletion_lock` (THE lock, see §6),
  `metadata::Dict` (root-scoped — `get_metadata`/`set_metadata!` always walk to
  root), dom uuid counter, msgpack scratch pool, and the close handshake fields
  (`closing::Bool`, `dispatch_count`).
- `Session{Connection}` is either the root wrapper (its `parent_or_root` is the
  `RootSession`) or a subsession (`parent_or_root` points at the parent
  `Session`). Subs are lightweight: they share connection/inbox/locks through
  the parent chain and own only per-render state: `children::Dict{String,Session}`,
  `session_objects` (markers; real entries live on root), `message_queue`,
  `on_document_load`, `connection_ready::Channel`, `on_close`/`on_open`
  observables, `deregister_callbacks`, asset-server handle, imports,
  stylesheets, `current_app`, `io_context`.
- THE SESSION TREE IS THE REGISTRY: `get_session(session, id)` recursively
  walks `children`. Don't build side tables mapping ids to sessions.
- Status walk: `UNINITIALIZED → RENDERED` (session_dom ran) `→ DISPLAYED`
  (html handed out; cleanup timer starts) `→ OPEN` (frontend connected) `→
  SOFT_CLOSED` (ws dropped, reconnect window per CleanupPolicy) `→ CLOSED`.
- Session ids: bare uuid4 normally; `"<prefix>/<uuid>"` under a
  `ProxyConnection` (`proxied_session_id`) — the prefix is the routing
  namespace (§9).

### Lifecycle / teardown

- `close(session)` dispatches to `close_root_session` / `close_subsession`.
  Roots additionally drain in-flight observable dispatches
  (`drain_dispatch!`: set `closing` under the lock, wait `dispatch_count → 0`
  OUTSIDE it, bounded 5s), then close children (children remove themselves
  from the parent), `free`, close asset server, inbox, connection.
- `free(session)` un-caches this session's objects from the ROOT cache
  (refcount via `CachedEntry.owners`, §5), clears queues/listeners/asset
  bookkeeping, sets CLOSED. Roots skip refcounting and `force_delete!`
  everything.
- **on_close listeners always fire OUTSIDE `deletion_lock`** (captured+cleared
  under it) so they may call `evaljs_value` etc. without deadlock. Same
  pattern for UpdateObservable listener dispatch (§4).
- `detach_subsession!` is the double-buffer variant: CLOSED-but-asset-server-
  alive for one more render so in-flight bundle fetches resolve; a later
  `close_subsession` finishes (idempotent; re-entrancy bounded by the cleared
  listener set).
- Ownership idiom: whoever mounts remote/external state registers teardown on
  `on(session.on_close)` — see `embed_app` (§9) for the reference.

## 2. Rendering & delivery — `session.jl`, `rendering/`, `app.jl`

- `rendered_dom(session, app)`: runs the App handler, applies `jsrender`,
  wraps errors via `handle_render_error` into inline error HTML +
  `record_session_error!` (surfaced by `isready(session)` which throws the
  recorded error, consume-on-read).
- `jsrender(session, x)`: session-specific methods first; generic fallback
  `jsrender(x)` and then `render_mime` with the richest mime (text/html →
  `HTML{String}`, images → `BinaryAsset` `<img>`, latex → KaTeX, text/plain →
  pre-wrap span, ANSI → RichText). NOTE: `jsrender(::Session, ::String)`
  returns a String (valid CHILD, not a Node) — `session_dom(session, ::App)`
  wraps non-Node handler results in a div so `App(value)` works for any
  showable.
- `session_dom(session, dom::Node; init, html_document)`: builds the fragment
  (`class="bonito-fragment"`, `dataJscallId="root"|"subsession-application-dom"`)
  or full document; injects stylesheets, asset-server setup, connection setup
  (ROOT ONLY — subs share the root transport), and — when `init=true` — the
  `Bonito.init_session(id, <bundle>, type, compression)` script where
  `<bundle>` is `fetch_binary(url)` of ONE `BinaryAsset` containing
  `get_messages!(session)` (queued messages + on_document_load as EvalJS).
  Ordering constraint documented inline: `push_dependencies!` must run AFTER
  `get_messages!` because message serialization is what registers `$(ES6Module)`
  imports.
- Sub-delivery paths (all end in ONE atomic message):
  - `update_session_dom!(parent, node_uuid, app)` → `UpdateSession` (msg 12)
    `{session_id, session_status, messages, html, replace, dom_node_selector}`
    sent via the ROOT; the JS handler polls the node and applies html+messages
    together.
  - `dom_in_js(parent, html, js_func)` → render sub with init inline, hand the
    node to a JS placer (the chat's lazy tool bodies use this).
  - `update_subsession_dom!(sub, selector, app)` — re-render an EXISTING sub
    (used by the GetSessionDOM pull, §3).
- Deferred render idiom (`display.jl`, `juliavscode/html` path): create
  `sub = Session(parent)`, set `sub.current_app[] = app`, render NOTHING; ship
  a stub that sends `{msg_type:"13" (GetSessionDOM), session: sub.id,
  replace: uuid(sub, node)}` from the page. Julia's handler frees + reopens
  the sub and re-delivers via `update_subsession_dom!`. Pull-based,
  idempotent, serialize-on-request — THE pattern for late/remote mounting.

## 3. Wire protocol — `serialization/protocol.jl`, JS `Connection.js`/`Sessions.js`

Msg types: `UpdateObservable "0"`, `OnjsCallback "1"`, `EvalJavascript "2"`,
`JavascriptError "3"`, `JavascriptWarning "4"`, `RegisterObservable "5"`,
`JSDoneLoading "8"`, `FusedMessage "9"`, `CloseSession "10"`, `PingPong "11"`,
`UpdateSession "12"`, `GetSessionDOM "13"`.

`process_message(session, data)` (inbound from the page):
- FIRST tries `route_to_remote` (§9) — worker-namespaced frames never touch
  local handling.
- `UpdateObservable`: object looked up + dispatch slot claimed under
  `deletion_lock` (guarded by `closing`), listener invoked OUTSIDE the lock
  with `update_nocycle!(obj, payload, session)` — the originating session's JS
  updater is skipped (no echo), other sessions sharing the observable still
  update. `dispatch_count` is what `close` drains.
- `JSDoneLoading`: error variant records on `init_error`; success resolves the
  sub via locked `get_session` walk and fires `sub.on_connection_ready(sub)`
  async — this is what flips `connection_ready`/flushes the queue via
  `init_session` (Julia side, §4).
- `CloseSession`: sub → `close(sub)`; root → `empty!` (roots are reused);
  client-controlled field is validated, never trusted.
- `GetSessionDOM`: async + fully locked: `free(sub)` (re-render from scratch),
  re-attach to children, `open!`, `update_subsession_dom!` → UpdateSession.

JS side (`Sessions.js`):
- `init_session(id, bundle_promise|null, status, compression)` registers the
  session, decodes+replays the bundle under `lock_loading`, then
  `done_initializing_session` → sends JSDoneLoading.
- `update_session_dom(msg)` (msg 12 handler): `on_node_available(selector)`
  polls the DOM (max 30s) OUTSIDE the loading lock, then applies
  `update_or_replace` + replays messages under it. Mount-into-late-DOM is
  therefore safe.
- Deletion is JULIA-FIRST by design (comment above `close_session`): JS sends
  CloseSession → Julia un-tracks → Julia sends `free_session(id)` → JS frees
  objects. Freeing JS-side first would race Julia serializing references to
  objects about to disappear. Never bypass this order.
- `GLOBAL_OBJECT_CACHE` is page-global; sessions hold key sets. `TrackingOnly`
  keys must already exist in the cache (warns otherwise — that warn means a
  broken delivery assumption, see §0/§5).

## 4. The send path — `_send` in `session.jl`

Under the root's `deletion_lock`: if `isready(session)` (connection_ready AND
open) write directly (write failure falls back to queue); else push to
`session.message_queue`. `init_session` (Julia, `session.jl` top) is the other
half: it drains queue+on_document_load into ONE fused bundle, writes it with
the lock RELEASED, then flips `connection_ready` and flushes stragglers — the
lock choreography exists to prevent (a) messages stranded in the queue, (b)
later sends overtaking the init bundle, (c) `push!` racing `get_messages!`.
Offline (`NoConnection`): `isopen` is false so everything queues; exports fuse
the queue into the static bundle — which is why message-ORDER-dependent
features (e.g. glyph batches as EvalJS events) replay correctly in
`export_static` output.

## 5. Serialization & the object cache — `serialization/`

- `SerializedMessage(session, msg)` packs eagerly at enqueue time (msgpack +
  optional compression), so a message's object registrations are fixed when it
  is CREATED, not when flushed.
- `add_cached!(create, session, send_to_js, object)`: key = `cache_key(session,
  object)` (PREFIXED under ProxyConnection). Root holds `CachedEntry(object,
  owners::Set{session ids})`; subs hold marker keys. First cacher serializes
  fully (and `register_observable!` attaches the JS-update listener EXACTLY
  once — insert into `root.session_objects` only AFTER `create_cached_object`,
  see inline comment); later cachers add themselves as owners and send
  `TrackingOnly(key)`.
- `dedup_cached_objects(root)::Bool` gates the TrackingOnly branch: `false`
  for `Session{<:ProxyConnection}` because proxied sub-fragments mount
  independently — a page may never have received the first owner's frame
  (the §0 invariant doesn't hold there), so every fragment ships full objects.
- `evaljs_value` builds a throwaway comm Observable OUTSIDE session lifetime —
  it must free it manually on both sides (JS `force_free_object`, Julia
  `remove_js_updates!` + cache deletion by the PREFIXED key).

## 6. Locking discipline

One lock per tree: `root.deletion_lock` (reentrant). Held for: cache/children
mutation, status transitions, queue/write decision, `get_session` walks,
session_dom. NEVER held across: user listeners (UpdateObservable dispatch,
on_close), the init-bundle socket write, `on_node_available`-style waits.
`cleanup_server` documents the one ordering hazard: never take
`websocket_routes.lock` around `close(session)` (which takes deletion_lock →
routes lock); snapshot under the routes lock, close outside.

## 7. Connections — `connection/`

- Interface (`connection.jl`): `write(conn, bytes)`, `isopen`, `open!`,
  `setup_connection(session)::Union{JSCode,Nothing}`, optional `write_large`,
  `use_parent_session(::Session{C})` (true for IJulia/Pluto: one long-lived
  page session, apps render as subs — `force_subsession!` forces the same
  mode, e.g. for workers/Documenter).
- `WebSocketConnection` (`websocket.jl`): per-root ws route `"/<session.id>"`;
  `run_connection_loop` pumps frames into `root.inbox`; reconnects swap the
  socket under `WebSocketHandler.lock`, stale loops detect via
  `is_current_socket` and do NOT tear down. `soft_close` + `CleanupPolicy`
  (default: 30s never-connected timeout; `cleanup_time` hrs reconnect window
  after ws drop) drive the 1 Hz `cleanup_server` task per Server.
- `WebSocketHandler.write` THROWS on failed send (after closing) so `_send`
  can queue-for-replay instead of silently dropping.
- `WebSocketIO` (`websocket-io.jl`): frames→IO adapter (Malt dial-backs etc.).
- `registry.jl`: connection/asset-server defaults = last-registered condition
  that returns non-nothing; `force_connection!`/`force_asset_server!`
  override; `Page()` composes these for notebook/export environments.

## 8. The overloadable rendering surface — one App, every target

The `(connection, asset_server)` pair on a session IS the target platform:
live HTTP server, notebook, static export, proxied worker. All rendering
primitives dispatch on it, which is why a single App works everywhere with no
target-specific code. When adding an asset-server or connection type, this is
the interface to implement:

Asset side (dispatch on the `AbstractAssetServer` subtype):
- `url(server, asset)` — WHERE the bytes are reachable: `HTTPAssetServer` /
  `ChildAssetServer` → registered `/assets/<content-hash-key>` route (with
  refcounting, §9); `NoServer` → `data:` URL (fully inlined page, nothing
  served); `AssetFolder`/`DocumenterAssets` → the file is WRITTEN into the
  export folder and a page-relative path returned; `online_path` short-circuits
  everything (CDN assets).
- `render_asset(session, server, asset)` — the `<script>`/`<link>` element
  emitted into the head by `push_dependencies!`. NoServer's ES6 variant can't
  use `<script src=data:… type=module>` for importable modules — it evaluates
  `BONITO_IMPORTS['<key>'] = import(<data-url>)` instead.
- `import_in_js(io, session, server, asset)` (`js_source.jl` calls this when
  printing a `$(ES6Module)` interpolation) + `import_js_url(server, asset)` —
  how a module reference resolves INSIDE js code: plain url string (HTTP),
  `new URL(rel, window.location.…)` fixups (folders), `BONITO_IMPORTS[key]`
  lookup (NoServer), `"./<basename>"` (Documenter, module-relative).
- `inline_code(session, server, source)` — how the `init_session` bootstrap
  script is embedded (NoServer: as a `data:` module so exports stay one file).
- `setup_asset_server(server)` — one-time page-top bootstrap node, `nothing`
  for most.
- `Base.close(server)` — release refs (ChildAssetServer decrefs its keys).

Connection side (dispatch on the `FrontendConnection` subtype):
- `setup_connection(session)` — returns the JS that OPENS the transport from
  the page (`setup_websocket_connection_js` for `WebSocketConnection`; comm
  hooks for IJulia/Pluto; `nothing` for `NoConnection` and `ProxyConnection` —
  the latter because the HOST owns the browser socket and a second one would
  be wrong). Injected for ROOT sessions only (§2).
- `Base.write`/`write_large`/`isopen`/`open!`/`close` — the transport verbs
  `_send` and `init_session` drive.
- `use_parent_session(::Session{C})` — page-session mode (IJulia/Pluto: one
  long-lived root per page, every display a sub; `force_subsession!` forces
  the same for workers/Documenter).
- `registry.jl` picks defaults: last-registered condition wins,
  `force_connection!`/`force_asset_server!` override, `Page()` bundles the
  common notebook/export configurations.

The practical consequence: NEVER special-case "am I exporting/in a notebook/
proxied" inside a widget — express the difference as an asset-server or
connection method and the whole rendering pipeline follows.

## 9. Proxy / remote sessions — `connection/proxy.jl`, `asset-serving/proxy.jl`

The transport-blackbox layer: `browser ↔ host ↔ (in-process | remote) julia`
with IDENTICAL session semantics (§0 must keep holding!).

- Verbs a driver implements: `proxy_send` (worker→browser frame),
  `proxy_asset_add/remove` (asset refcount 0→1/1→0 crossings),
  `proxy_forward` (browser→worker decoded frame), `proxy_fetch` (asset byte
  range). `InProcessProxy` is the reference driver; a ws driver (BonitoAgents'
  EvalBridge / RemoteProxy.BridgeDriver) implements the same verbs over a
  socket.
- `ProxyConnection{D}` namespaces EVERYTHING under `prefix`: object cache keys
  (`cache_key`), dom uuids, session ids (`proxied_session_id`). That prefix is
  the ENTIRE routing table: the host registers `RemoteSession(prefix, driver)`
  (root metadata, `register_remote!`) and `route_to_remote` forwards inbound
  frames whose route id (`UpdateObservable` → object id;
  `JSDoneLoading`/`CloseSession`/`GetSessionDOM` → session id) matches
  `prefix` or `prefix/…`. The host mirrors NOTHING.
- `render_proxied(app, prefix; driver, asset_server)`: fresh proxied ROOT
  session, `session_dom(...; init=false)`, html string + init messages as one
  `BinaryAsset` url → `ProxyRender`. `RemoteApp`'s jsrender mounts it with
  `on_document_load → init_session(prefix, fetch_binary(init_url))` (rides the
  same bundle as the surrounding DOM — works through innerHTML mounts).
- `embed_app(host, app)` is the OWNERSHIP reference: per-embed root (own
  prefix = own cache scope), route registered on host, and
  `on(host.on_close)`: unregister route, `free_session` in the browser, close
  the worker session.
- Proxied assets: worker `ProxyAssetRegistry` refcounts; 0→1 ships
  `proxy_asset_add` (eager bytes ≤256KB else lazy); host stores `RemoteAsset`
  in its `HTTPAssetServer` via a per-bridge `ChildAssetServer` and serves
  ranges via `proxy_fetch_timed` (30s bound → 504, never a wedged HTTP task).
  `register!` re-registration adopts the NEWEST asset (keys are content
  hashes; the latest registrant's driver is the live one — old entries may
  point at dead bridges).

## 10. Display & export — `display.jl`, `export.jl`

- `show_html(io, app; parent=CURRENT_SESSION[])`: with a parent → sub render
  (fragment); without → root, honoring `_use_parent_session` (page-session
  mode renders an empty root + the app as a sub).
- `export_static(target, app; session/connection/asset_server)`: a
  `NoConnection`+`NoServer` session, `page_html` → full document; everything
  the render queued (INCLUDING plain EvalJS events, in order) fuses into the
  init bundle. `Routes` variant exports a folder tree with `AssetFolder`.

## 11. Gotchas that already caused real bugs

- Any "X was already shipped" ledger (object cache, glyph atlas, asset
  registry) is scoped to §0's invariant. Fragments that serialize at time A
  and mount at time B (or never) break it; use pull/self-contained payloads
  or the deferred-render idiom (§2) instead of push-once.
- Long-running loop tasks (ws relay/read loops) never see method
  redefinitions (world age) — instrument by restarting the loop/process, not
  by `@eval` wrapping.
- `Uint32Array.map(f)` in JS coerces results back to numbers; use
  `Array.from(arr, f)` when producing string keys.
- ES6Module bundles: editing an IMPORTED file doesn't bump the entry's mtime —
  delete the `.bundled.js` (or `rebundle!`); a running process also caches
  bundle bytes in memory.
- `io_context` is PER SESSION (each sub carries its own; `show_html` sets it),
  but `metadata` is ALWAYS root-scoped (`get_metadata` walks to the root).
  Never put per-fragment/per-sub state in metadata — every sub of the tree
  sees and shares it.
