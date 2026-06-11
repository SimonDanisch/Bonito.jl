"""
The string part of JSCode.
"""
struct JSString
    source::String
end

"""
Javascript code that supports interpolation of Julia Objects.
Construction of JSCode via string macro:
```julia
jsc = js"console.log(\$(some_julia_variable))"
```
This will decompose into:
```julia
jsc.source == [JSString("console.log("), some_julia_variable, JSString("\"")]
```
"""
struct JSCode
    source::Vector{Union{JSString, Any}}
    file::String # location of the js string, a la "path/to/file:line"
end

JSCode(source) = JSCode(source, "")

abstract type AbstractAsset end

"""
    AbstractConnectionIndicator

Abstract type for connection indicators. Custom indicators should subtype this.
Implementations should define `jsrender(session::Session, indicator::T)` where T is the subtype.
"""
abstract type AbstractConnectionIndicator end

"""
    Asset(path_or_url; name=nothing, es6module=false, check_isfile=false, bundle_dir=nothing, mediatype=:inferred)

Represent an asset (JavaScript, CSS, image, etc.) that can be included in a Bonito DOM.

# Arguments
- `path_or_url`: Local file path or URL to the asset
- `name`: Optional name for the asset. For JS assets, this becomes the global variable name when loaded.
          Defaults to the filename without extension for JS files (e.g., "ace.js" → "ace")
- `es6module`: Whether this is an ES6 module that needs bundling (default: false)
- `check_isfile`: Verify that local files exist (default: false)
- `bundle_dir`: Directory for bundled ES6 modules (default: inferred)
- `mediatype`: Media type symbol (:js, :css, :png, etc.). Auto-detected from extension if not specified

# JavaScript Asset Loading

## Non-module scripts (es6module=false)

For non-module JavaScript assets, interpolating the asset in JS code creates a Promise
that resolves with the global object:

```julia
ace_asset = Asset("https://cdn.jsdelivr.net/gh/ajaxorg/ace-builds/src-min/ace.js")
# name defaults to "ace" (inferred from filename)

js\"""
    \$(ace_asset).then(ace => {
        // ace object is now available
        const editor = ace.edit(element);
    });
\"""
```

To override the global name:
```julia
Asset("https://example.com/mylibrary.js"; name="MyLib")
```

## ES6 modules (es6module=true)

For ES6 modules, use the `ES6Module(path)` constructor which automatically sets `es6module=true` and
bundles the module with its dependencies. ES6 modules also support the `.then()` syntax:

```julia
mod = ES6Module("path/to/module.js")  # name defaults to "module"

js\"""
    \$(mod).then(exports => {
        // ES6 module exports are now available
        exports.someFunction();
    });
\"""
```

# Fields
- `name::Union{Nothing, String}`: Asset name (used as global variable name for JS assets)
- `es6module::Bool`: Whether this is an ES6 module
- `media_type::Symbol`: Type of asset (:js, :css, :png, etc.)
- `online_path::String`: URL if asset is hosted online
- `local_path::Union{String, Path}`: Local file system path
- `bundle_file::Union{String, Path}`: Path to bundled file (ES6 modules only)
- `bundle_data::Vector{UInt8}`: Bundled file contents (ES6 modules only)
- `content_hash::RefValue{String}`: Hash of bundled content (ES6 modules only)

# See Also
- `ES6Module(path)`: Convenience constructor for ES6 modules with automatic bundling
"""
struct Asset <: AbstractAsset
    name::Union{Nothing, String}
    es6module::Bool
    media_type::Symbol
    # We try to always have online & local files for assets
    # If you only give an online resource, we will download it
    # to also be able to host it locally
    online_path::String
    local_path::Union{String, Path}

    # only used if es6module
    bundle_file::Union{String, Path}
    bundle_data::Vector{UInt8}
    content_hash::RefValue{String}
end


struct Link <: AbstractAsset
    target::String
end

struct JSException <: Exception
    exception::String
    message::String
    stacktrace::Vector{String}
end

js_to_local_stacktrace(asset_server, matched_url) = matched_url

function Base.show(io::IO, exception::JSException)
    println(io, "An exception was thrown in JS: $(exception.exception)")
    println(io, "Additional message: $(exception.message)")
    println(io, "Stack trace:")
    for line in exception.stacktrace
        println(io, "    ", line)
    end
end

abstract type FrontendConnection end
abstract type AbstractAssetServer end

"""
    SessionIO <: IO

Reusable IO scratch space for streaming nested msgpack Extension payloads. Held
on the owning `Session` so the IOBuffers that back nested-extension packing
(SerializedMessage → cache/data extensions → inner objects extension) are
allocated once per session and reused for every outbound message.

Internally:
* `output` — the destination IOBuffer (set per top-level pack call).
* `scratches` — a per-depth stack of reusable scratch IOBuffers; lazily grown,
  reset (capacity preserved) on each reuse via `reset_for_reuse!`.
* `depth` — current nesting depth; `0` writes go to `output`, `>=1` go to
  `scratches[depth]`.
* `lock` — single-task happy path on a `ReentrantLock`. Bonito.send is normally
  serialized through one Task but yield points within a packing call could let
  another Task try to use the same `SessionIO`, so we guard it.
"""
mutable struct SessionIO <: IO
    output::Union{Nothing, IOBuffer}
    scratches::Vector{IOBuffer}
    depth::Int
    lock::Base.ReentrantLock
end

SessionIO() = SessionIO(nothing, IOBuffer[], 0, Base.ReentrantLock())

struct SessionCache
    session_id::String
    # Must preserve insertion order for nested observable serialization.
    # Inner observables must be deserialized before outer observables that reference them.
    objects::OrderedDict{String, Any}
    session_type::String
end

struct SerializedMessage
    cache::SessionCache
    data::Any
    compression::Bool
    # Captured from the originating Session so pack_type can stream through the
    # session's reusable scratch buffers without allocating per-message.
    pack_io::SessionIO
end

struct BinaryMessage
    bytes::Vector{UInt8}
end

@enum SessionStatus UNINITIALIZED RENDERED DISPLAYED OPEN CLOSED SOFT_CLOSED

struct CSS
    selector::String
    # TODO use some kind of immutable Dict
    attributes::Dict{String, Union{CSS, String, Asset}}
    # We assume attributes to be immutable, so we calculate the hash once
    hash::UInt64
    function CSS(selector, attributes::Dict{String,T}) where T <: Any
        css = Dict{String,Union{CSS,String,Asset}}()
        # Need to sort to always get the same hash!
        sorted_keys = sort!(collect(keys(attributes)))
        h = hash(selector, UInt64(0))
        h = hash(sorted_keys, h)
        for k in sorted_keys
            converted = convert_css_attribute(attributes[k])
            css[String(k)] = converted
            h = hash(converted, h)
        end
        return new(selector, css, h)
    end
end

Base.hash(css::CSS, h::UInt64) = hash(css.hash, h)
Base.:(==)(css1::CSS, css2::CSS) = css1.hash == css2.hash

"""
    Styles(css::CSS...)

Creates a Styles object, which represents a Set of CSS objects.
You can insert the Styles object into a DOM node, and it will be rendered as a `<style>` node.
If you assign it directly to `DOM.div(style=Style(...))`, the styling will be applied to the specific div.
Note, that per `Session`, each unique css object in all `Styles` across the session will only be rendered once.
This makes it easy to create Styling inside of components, while not worrying about creating lots of Style nodes on the page.
There are a two more convenience constructors to make `Styles` a bit easier to use:
```julia
Styles(pairs::Pair...) = Styles(CSS(pairs...))
Styles(priority::Styles, defaults...) = merge(Styles(defaults...), priority)
```
For styling components, it's recommended, to always allow user to merge in customizations of a Style, like this:
```julia
function MyComponent(; style=Styles())
    return DOM.div(style=Styles(style, "color" => "red"))
end
```
All Bonito components are stylable this way.

!!! info
    Why not `Hyperscript.Style`? While the scoped styling via `Hyperscript.Style` is great, it makes it harder to create stylable components, since it doesn't allow the deduplication of CSS objects across the session.
    It's also significantly slower, since it's not as specialized on the deduplication and the camelcase keyword to css attribute conversion is pretty costly.
    That's also why `CSS` uses pairs of strings instead of keyword arguments.

"""
struct Styles
    # OrderedDict(selector => CSS) - preserves insertion order for media queries
    styles::OrderedDict{String, CSS}
end

const HTMLElement = Node{Hyperscript.HTMLSVG}

"""
    ConnectionIndicator <: AbstractConnectionIndicator

Default connection indicator showing connection status as an LED-like circle.
See the full documentation with `?ConnectionIndicator` after loading Bonito.
"""
struct ConnectionIndicator <: AbstractConnectionIndicator
    connected_color::String
    connecting_color::String
    disconnected_color::String
    no_connection_color::String
    size::Int
    position::String
    top::String
    right::String
    style::Styles
    # When the JS-side websocket exhausts its retry budget (~30s by default)
    # the LED alone is too easy to miss. With `offline_banner=true` (default)
    # we also pop a fixed top banner with a Reload button so the operator gets
    # an unambiguous prompt instead of a silently-dead page. Set false to
    # restore the LED-only behavior.
    offline_banner::Bool
    offline_message::String
    offline_button_label::String
    # Reactive slot for the most-recent server-side error on the session(s)
    # rendering this indicator. Set by `record_session_error!` (the same
    # places `Session.init_error[]` is set) and rendered into the indicator
    # DOM via `map(render_error, indicator.error)`, so the cause shows up in
    # the page itself instead of just the Julia logs. Holds the raw
    # Exception object so a richer renderer can dispatch on type / inspect
    # fields rather than parsing a stringified message.
    error::Observable{Union{Nothing, Exception}}
end

function ConnectionIndicator(;
    connected_color::String="#22c55e",
    connecting_color::String="#eab308",
    disconnected_color::String="#ef4444",
    no_connection_color::String="#6b7280",
    size::Int=10,
    position::String="fixed",
    top::String="10px",
    right::String="10px",
    style::Styles=Styles(),
    offline_banner::Bool=true,
    # Phrased so a routine idle drop (laptop slept, tab backgrounded, server
    # restarted) reads as "expected — just reload" instead of "something
    # broke". "Paused" rather than "lost" because state on the server side
    # generally survives a reload (apps that put their state in
    # ServerState-style structs, like BonitoTeam, recover transparently).
    offline_message::String="Connection paused after idle. Reload to reconnect.",
    offline_button_label::String="Reload",
    error::Observable{Union{Nothing, Exception}}=Observable{Union{Nothing, Exception}}(nothing),
)
    return ConnectionIndicator(
        connected_color,
        connecting_color,
        disconnected_color,
        no_connection_color,
        size,
        position,
        top,
        right,
        style,
        offline_banner,
        offline_message,
        offline_button_label,
        error,
    )
end

"""
Root-only session state. One `RootSession` exists per real connection (per
session tree). Holds the OS-level connection, the receive inbox, deletion
lock, msgpack scratch IO, and other resources that subsessions share via
their parent chain rather than duplicating per-sub.

A subsession's "where do I belong" is its parent `Session`; a root's is
this `RootSession`. The two cases are mutually exclusive — encoded by
the `Session.parent_or_root::Union{RootSession{Con}, Session{Con}}` field.
"""
mutable struct RootSession{Connection <: FrontendConnection}
    connection::Connection
    inbox::Channel{Vector{UInt8}}
    js_comm::Observable{Union{Nothing, Dict{String, Any}}}
    # For rendering Hyperscript.Node and giving them a unique id inside the
    # session tree. Atomic because `uuid(session, node)` (in
    # rendering/hyperscript_integration.jl) is called from any task that touches
    # a render — concurrent renders would otherwise hand out the same id to
    # multiple nodes, causing JS-side DOM lookups by data-jscall-id to collide.
    # See test/race_conditions_audit.jl F6.
    dom_uuid_counter::Threads.Atomic{Int}
    compression_enabled::Bool
    deletion_lock::Base.ReentrantLock
    threadid::Int
    # User metadata storage. Always accessed via the root.
    metadata::Dict{Symbol, Any}
end

"""
A web session — the root of a session tree, or a subsession attached to a
parent. The `parent_or_root` field encodes which: a `RootSession{Con}` for a
root, a parent `Session{Con}` for a subsession (`isroot(s)` discriminates).

Subsessions are intentionally lightweight: they share the root's connection,
inbox, locks, and msgpack scratch via the parent chain. They allocate only
their own per-render state (asset_server handle, on_close, session_objects,
imports, stylesheets, etc.).
"""
mutable struct Session{Connection <: FrontendConnection}
    # Set at construction, never reassigned (Julia 1.8+ `const` field).
    # - `RootSession{Con}`  → this session is the root of the tree
    # - `Session{Con}`      → this session is a sub; field points to its parent
    const parent_or_root::Union{RootSession{Connection}, Session{Connection}}
    status::SessionStatus
    closing_time::Float64
    children::Dict{String, Session{Connection}}
    id::String
    # The way we serve any file asset.
    asset_server::AbstractAssetServer
    # Outgoing messages waiting for the connection to come up. Each session has
    # its own queue; `init_session` flushes per-session on the JS-side ready signal.
    message_queue::Vector{SerializedMessage}
    # Code that gets evalued last after all other messages, when this session
    # gets connected.
    on_document_load::Vector{JSCode}
    # One-shot signal flipped when this session's frontend reports ready.
    connection_ready::Channel{Bool}
    on_connection_ready::Function
    # Recorded failure for this session: either a frontend init error (set by
    # protocol.jl when JS reports an exception during init) or a render-time
    # error (set by `handle_render_error` in `rendered_dom`'s catch). Surfaced
    # by `isready(session)` (which throws it by default), so any
    # `wait_for_ready` or runtime check learns the cause instead of seeing a
    # silent closed session. Sites that only care about connection state opt
    # out with `isready(session; throw=false)`.
    init_error::RefValue{Union{Nothing, Exception}}
    on_close::Observable{Bool}
    # Notified (with `true`) every time a frontend connection is established
    # for this session - both the initial connect and websocket reconnects
    # (fired by `init_session` after the queued messages were flushed).
    # Integrations that treat the frontend as a cache of julia-side state
    # (e.g. WGLMakie) use this to re-synchronize on reconnect.
    on_open::Observable{Bool}
    deregister_callbacks::Vector{Observables.ObserverFunction}
    session_objects::Dict{String, Any}
    # Per-session message filter — `_send` consults this to drop outgoing
    # messages when the export pipeline is recording state.
    ignore_message::RefValue{Function}
    # For rendering Styles.
    style_counter::Int
    imports::OrderedSet{Asset}
    global_stylesheets::OrderedSet{Styles}
    title::String
    current_app::RefValue{Any}
    io_context::RefValue{Union{Nothing, IOContext}}
    stylesheets::OrderedDict{HTMLElement, OrderedSet{CSS}}
    # Reusable scratch IO for streaming nested msgpack Extension payloads.
    # Per-session because pack hot-paths take this lock — root-shared would
    # serialize concurrent renders across sub-sessions unnecessarily.
    pack_io::SessionIO
end

# ───── Lineage / accessors ─────────────────────────────────────────────────

"""
    isroot(s::Session) -> Bool

True if `s` is the root of its session tree (its `parent_or_root` is the
`RootSession`, not a parent `Session`).
"""
isroot(s::Session) = getfield(s, :parent_or_root) isa RootSession

"""
    parent(s::Session) -> Union{Session, Nothing}

Parent session, or `nothing` for roots. Matches the old `session.parent`
semantics so callers don't need to change.
"""
function Base.parent(s::Session)
    p = getfield(s, :parent_or_root)
    return p isa Session ? p : nothing
end

"""
    root_session(s::Session) -> Session

The root `Session` of `s`'s session tree. Returns `s` itself if `s` is a root.
"""
function root_session(s::Session{Con}) where {Con}
    cur = s
    while !isroot(cur)
        cur = getfield(cur, :parent_or_root)::Session{Con}
    end
    return cur
end

"""
    root_data(s::Session) -> RootSession

The `RootSession` shared by everything in `s`'s session tree. Convenience for
accessing root-only state (connection, inbox, locks, ...).
"""
function root_data(s::Session{Con}) where {Con}
    return getfield(root_session(s), :parent_or_root)::RootSession{Con}
end

# ───── Convenience accessors for root-only fields ──────────────────────────

inbox(s::Session)               = root_data(s).inbox
connection(s::Session)          = root_data(s).connection
js_comm(s::Session)             = root_data(s).js_comm
dom_uuid_counter(s::Session)    = root_data(s).dom_uuid_counter
compression_enabled(s::Session) = root_data(s).compression_enabled
deletion_lock(s::Session)       = root_data(s).deletion_lock
threadid_of(s::Session)         = root_data(s).threadid
metadata_dict(s::Session)       = root_data(s).metadata

# ───── getproperty / setproperty! shim ─────────────────────────────────────
# Existing call sites use `session.foo` for fields that have moved to
# RootSession. Route them through `root_data` so we don't have to rewrite
# every caller in this refactor.

const ROOT_ONLY_FIELDS = (
    :connection, :inbox, :js_comm, :dom_uuid_counter,
    :compression_enabled, :deletion_lock, :threadid, :metadata,
)

function Base.getproperty(s::Session, f::Symbol)
    if f === :parent
        return parent(s)
    end
    if f in ROOT_ONLY_FIELDS
        return getfield(root_data(s), f)
    end
    return getfield(s, f)
end

function Base.setproperty!(s::Session, f::Symbol, v)
    if f === :parent_or_root
        error("Session.parent_or_root is `const`; set via the constructor")
    end
    if f === :parent
        error("Session.parent is computed from parent_or_root; set via the constructor")
    end
    if f in ROOT_ONLY_FIELDS
        return setfield!(root_data(s), f, v)
    end
    return setfield!(s, f, v)
end

function Base.propertynames(s::Session, private::Bool=false)
    direct = (
        :parent_or_root, :parent, :status, :closing_time, :children, :id,
        :asset_server, :message_queue, :on_document_load, :connection_ready,
        :on_connection_ready, :init_error, :on_close, :on_open, :deregister_callbacks,
        :session_objects, :ignore_message, :style_counter, :imports,
        :global_stylesheets, :title, :current_app, :io_context, :stylesheets,
        :pack_io,
    )
    return (direct..., ROOT_ONLY_FIELDS...)
end

struct BinaryAsset <: AbstractAsset
    data::Vector{UInt8}
    mime::String
end

function BinaryAsset(session::Session, @nospecialize(data))
    BinaryAsset(serialize_binary(session, data), "application/octet-stream")
end

function Base.show(io::IO, asset::BinaryAsset)
    print(io, "BinaryAsset($(asset.mime)) with $(length(asset.data)) bytes")
end

"""
Creates a Julia exception from data passed to us by the frondend!
"""
function JSException(session::Session, js_data::AbstractDict)
    stacktrace = String[]
    # The Dict values infer as Any; convert eagerly so this method carries no
    # `convert(String, ::Any)` edges - those get invalidated by any package
    # adding a `convert(::Type{String}, ...)` method (JSON, FilePathsBase, ...)
    trace = String(js_data["stacktrace"])::String
    if trace != "nothing"
        for line in split(trace, "\n")
            push!(stacktrace, String(js_to_local_stacktrace(session.asset_server, line))::String)
        end
    end
    return JSException(String(js_data["exception"])::String, String(js_data["message"])::String, stacktrace)
end

"""
    Session(connection::FrontendConnection=default_connection(); kwargs...) -> Session

Construct a new root session. Allocates a fresh `RootSession` (holding the
connection, inbox, locks, msgpack scratch, etc.), spawns the inbox-reader
task, and returns the wrapping `Session`.
"""
function Session(connection::Connection=default_connection();
                 id=string(uuid4()),
                 asset_server=default_asset_server(),
                 message_queue=SerializedMessage[],
                 on_document_load=JSCode[],
                 connection_ready=Channel{Bool}(1),
                 on_connection_ready=init_session,
                 init_error=Ref{Union{Nothing, Exception}}(nothing),
                 js_comm=Observable{Union{Nothing, Dict{String, Any}}}(nothing),
                 on_close=Observable(false),
                 on_open=Observable(false),
                 deregister_callbacks=Observables.ObserverFunction[],
                 session_objects=Dict{String, Any}(),
                 imports=OrderedSet{Asset}(),
                 title="Bonito App",
                 compression_enabled=default_compression(),
                 ignore_message=RefValue{Function}(x -> false),
                 n_inbox=Inf) where {Connection <: FrontendConnection}
    inbox = Channel{Vector{UInt8}}(n_inbox)
    root_state = RootSession{Connection}(
        connection,
        inbox,
        js_comm,
        Threads.Atomic{Int}(0),
        compression_enabled,
        Base.ReentrantLock(),
        Threads.threadid(),
        Dict{Symbol, Any}(),
    )
    session = Session{Connection}(
        root_state,                                     # parent_or_root
        UNINITIALIZED,                                  # status
        time(),                                         # closing_time
        Dict{String, Session{Connection}}(),            # children
        id,
        asset_server,
        message_queue,
        on_document_load,
        connection_ready,
        on_connection_ready,
        init_error,
        on_close,
        on_open,
        deregister_callbacks,
        session_objects,
        ignore_message,
        1,                                              # style_counter
        imports,
        OrderedSet{Styles}(),                           # global_stylesheets
        title,
        RefValue{Any}(nothing),                         # current_app
        RefValue{Union{Nothing, IOContext}}(nothing),   # io_context
        OrderedDict{HTMLElement, OrderedSet{CSS}}(),    # stylesheets
        SessionIO(),                                    # pack_io
    )
    # Inbox reader task. Captures `session` by reference so `process_message`
    # can find it. The Channel keeps the task alive (via `bind`); the task
    # exits when the channel is closed by `close(session)`. Julia's GC
    # collects the resulting Session ↔ inbox ↔ task ↔ closure cycle once
    # nothing outside it holds the session.
    task = Task() do
        for message in inbox
            @async try
                process_message(session, message)
            catch e
                @warn "error while processing received msg" exception = (
                    e, Base.catch_backtrace()
                )
            end
        end
    end
    bind(inbox, task)
    schedule(task)
    return session
end

"""
    Session(parent_session::Session; kwargs...) -> Session

Create a sub-session attached to `parent_session`. Sub-sessions reuse the
root's connection, inbox, locks, and msgpack scratch via the parent chain;
only their per-render state (asset_server handle, on_close, session_objects,
imports, stylesheets) is allocated fresh. No inbox task is spawned for subs.
"""
function Session(parent_session::Session{Connection};
                 asset_server=similar(parent_session.asset_server),
                 on_connection_ready=init_session,
                 title=parent_session.title) where {Connection <: FrontendConnection}
    root = root_session(parent_session)
    return lock(deletion_lock(root)) do
        sub = Session{Connection}(
            parent_session,                                  # parent_or_root
            UNINITIALIZED,
            time(),
            Dict{String, Session{Connection}}(),             # children
            string(uuid4()),                                 # id
            asset_server,
            SerializedMessage[],                             # message_queue
            JSCode[],                                        # on_document_load
            Channel{Bool}(1),                                # connection_ready
            on_connection_ready,
            Ref{Union{Nothing, Exception}}(nothing),         # init_error
            Observable(false),                               # on_close
            Observable(false),                               # on_open
            Observables.ObserverFunction[],                  # deregister_callbacks
            Dict{String, Any}(),                             # session_objects
            RefValue{Function}(x -> false),                  # ignore_message
            1,                                               # style_counter
            OrderedSet{Asset}(),                             # imports
            OrderedSet{Styles}(),                            # global_stylesheets
            title,
            RefValue{Any}(nothing),                          # current_app
            RefValue{Union{Nothing, IOContext}}(nothing),    # io_context
            OrderedDict{HTMLElement, OrderedSet{CSS}}(),     # stylesheets
            SessionIO(),                                     # pack_io
        )
        parent_session.children[sub.id] = sub
        return sub
    end
end

function normalize_handler(handler)
    # Normalize to (session, request) -> DOM signature
    if handler isa Node
        return (session, request) -> handler
    elseif hasmethod(handler, Tuple{Session,HTTP.Request})
        return handler
    elseif hasmethod(handler, Tuple{Session})
        return (session, request) -> handler(session)
    elseif hasmethod(handler, Tuple{HTTP.Request})
        return (session, request) -> handler(request)
    elseif hasmethod(handler, Tuple{})
        return (session, request) -> handler()
    elseif !(handler isa Function)
        return (session, request) -> handler
    else
        error("""
        Handler function must have one of these signatures:
            handler() -> DOM
            handler(session::Session) -> DOM
            handler(request::Request) -> DOM
            handler(session, request) -> DOM
        """)
    end
end


function loading_page_handler(app, loadingpage, handler, session, request)
    # No live connection — render synchronously (e.g. export_static with NoConnection)
    if root_session(session).connection isa NoConnection
        return handler(session, request)
    end
    obs = Observable{Any}(loadingpage)
    app.loading_task[] = @async try
        obs[] = handler(session, request)
    catch err
        @debug "Error rendering app with loading_page" exception = (err, Base.catch_backtrace())
        obs[] = HTTPServer.err_to_html(err, Base.catch_backtrace())
    end
    return DOM.div(obs)
end

function create_handler(app, handler, loading_content)
    # No loading content - return normalized handler directly
    isnothing(loading_content) && return handler
    # Wrap with loading content
    return (s, r) -> loading_page_handler(app, loading_content, handler, s, r)
end

mutable struct App
    handler::Function
    session::Base.RefValue{Union{Session,Nothing}}
    title::String
    indicator::Union{Nothing,AbstractConnectionIndicator}
    loading_page::Any # Union{Nothing, LoadingPage} - LoadingPage defined later in components.jl
    loading_task::Base.RefValue{Union{Nothing, Task}}
    function App(
        handler::Any;
        title::AbstractString="Bonito App",
        indicator::Union{Nothing,AbstractConnectionIndicator}=nothing,
        loading_page=nothing,
    )
        n_handler = normalize_handler(handler)
        session = Base.RefValue{Union{Session,Nothing}}(nothing)
        loading_task = Base.RefValue{Union{Nothing, Task}}(nothing)
        app = new(n_handler, session, title, indicator, loading_page, loading_task)
        app.handler = create_handler(app, n_handler, loading_page)
        # No finalizer. Session lifetime is owned by `root.children` (or by a
        # buffer like `DisplayHandler.previous_session` / the observable
        # double-buffer in `jsrender(::Session, ::Observable)`); those owners
        # close the session when they replace it. The App itself just holds
        # a back-ref via `app.session[]`; dropping the App is harmless.
        return app
    end
end


struct Routes
    routes::Dict{String, App}
end

Routes() = Routes(Dict{String, App}())
Routes(pairs::Pair{String, App}...) = Routes(Dict{String, App}(pairs))
Base.setindex!(routes::Routes, app::App, key::String) = (routes.routes[key] = app)
