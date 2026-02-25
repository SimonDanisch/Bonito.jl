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

mutable struct SubConnection <: FrontendConnection
    connection::FrontendConnection
    isopen::Bool
end

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
    )
end

"""
A web session with a user
"""
mutable struct Session{Connection <: FrontendConnection}
    status::SessionStatus
    closing_time::Float64
    parent::Union{Session, Nothing}
    children::Dict{String, Session{SubConnection}}
    id::String
    # The connection to the JS frontend.
    # Currently can be IJuliaConnection, WebsocketConnection, PlutoConnection, NoConnection
    connection::Connection
    # The way we serve any file asset
    asset_server::AbstractAssetServer
    message_queue::Vector{SerializedMessage}
    # Code that gets evalued last after all other messages, when session gets connected
    on_document_load::Vector{JSCode}
    connection_ready::Channel{Bool}
    on_connection_ready::Function
    # Should be checkd on connection_ready to see if an error occured
    init_error::RefValue{Union{Nothing,JSException}}
    js_comm::Observable{Union{Nothing, Dict{String, Any}}}
    on_close::Observable{Bool}
    deregister_callbacks::Vector{Observables.ObserverFunction}
    session_objects::Dict{String, Any}
    # For rendering Hyperscript.Node, and giving them a unique id inside the session
    dom_uuid_counter::Int
    # For rendering Styles
    style_counter::Int
    ignore_message::RefValue{Function}
    imports::OrderedSet{Asset}
    global_stylesheets::OrderedSet{Styles}
    title::String
    compression_enabled::Bool
    deletion_lock::Base.ReentrantLock
    current_app::RefValue{Any}
    io_context::RefValue{Union{Nothing, IOContext}}
    stylesheets::OrderedDict{HTMLElement, OrderedSet{CSS}}
    inbox::Channel{Vector{UInt8}}
    threadid::Int
    # User metadata storage - accessed via root session
    metadata::Dict{Symbol, Any}

    function Session(
            parent::Union{Session, Nothing},
            children::Dict{String, Session{SubConnection}},
            id::String,
            connection::Connection,
            asset_server::AbstractAssetServer,
            message_queue::Vector{SerializedMessage},
            on_document_load::Vector{JSCode},
            connection_ready::Channel{Bool},
            on_connection_ready::Function,
            init_error::Ref{Union{Nothing, JSException}},
            js_comm::Observable{Union{Nothing, Dict{String, Any}}},
            on_close::Observable{Bool},
            deregister_callbacks::Vector{Observables.ObserverFunction},
            session_objects::Dict{String, Any},
            dom_uuid_counter::Int,
            ignore_message::RefValue{Function},
            imports::OrderedSet{Asset},
            title::String,
            compression_enabled::Bool,
            n_inbox = Inf
        ) where {Connection}
        inbox = Channel{Vector{UInt8}}(n_inbox)
        session = new{Connection}(
            UNINITIALIZED,
            time(),
            parent,
            children,
            id,
            connection,
            asset_server,
            message_queue,
            on_document_load,
            connection_ready,
            on_connection_ready,
            init_error,
            js_comm,
            on_close,
            deregister_callbacks,
            session_objects,
            dom_uuid_counter,
            1,
            ignore_message,
            imports,
            OrderedSet{Styles}(),
            title,
            compression_enabled,
            Base.ReentrantLock(),
            RefValue{Any}(nothing),
            RefValue{Union{Nothing,IOContext}}(nothing),
            OrderedDict{HTMLElement,OrderedSet{CSS}}(),
            inbox,
            Threads.threadid(),
            Dict{Symbol, Any}()
        )

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
    if js_data["stacktrace"] != "nothing"
        for line in split(js_data["stacktrace"], "\n")
            push!(stacktrace, js_to_local_stacktrace(session.asset_server, line))
        end
    end
    return JSException(js_data["exception"], js_data["message"], stacktrace)
end

function Session(connection=default_connection();
                id=string(uuid4()),
                asset_server=default_asset_server(),
                message_queue=SerializedMessage[],
                on_document_load=JSCode[],
                connection_ready=Channel{Bool}(1),
                on_connection_ready=init_session,
                init_error=Ref{Union{Nothing, JSException}}(nothing),
                js_comm=Observable{Union{Nothing, Dict{String, Any}}}(nothing),
                on_close=Observable(false),
                deregister_callbacks=Observables.ObserverFunction[],
                session_objects=Dict{String, Any}(),
                imports=OrderedSet{Asset}(),
                title="Bonito App",
                compression_enabled=default_compression())

    return Session(
        nothing,
        Dict{String, Session{SubConnection}}(),
        id,
        connection,
        asset_server,
        message_queue,
        on_document_load,
        connection_ready,
        on_connection_ready,
        init_error,
        js_comm,
        on_close,
        deregister_callbacks,
        session_objects,
        0,
        RefValue{Function}(x-> false),
        imports,
        title,
        compression_enabled,
    )
end

function Session(parent_session::Session;
    asset_server=similar(parent_session.asset_server),
    on_connection_ready=init_session, title=parent_session.title)
    root = root_session(parent_session)
    return lock(root.deletion_lock) do
        connection = SubConnection(root)
        session = Session(connection; asset_server=asset_server, on_connection_ready=on_connection_ready, title=title)
        session.parent = parent_session
        parent_session.children[session.id] = session
        return session
    end
end

mutable struct App
    handler::Function
    session::Base.RefValue{Union{Session,Nothing}}
    title::String
    indicator::Union{Nothing, AbstractConnectionIndicator}
    loading_page::Any # Union{Nothing, LoadingPage} - LoadingPage defined later in components.jl
    function App(handler::Function;
            title::AbstractString="Bonito App",
            indicator::Union{Nothing, AbstractConnectionIndicator}=nothing,
            loading_page=nothing,
            threaded=nothing)

        if threaded isa Bool
            @warn "The `threaded` argument is deprecated and has no effect. Each App is run in a thread created by HTTP.jl."
        end
        session = Base.RefValue{Union{Session, Nothing}}(nothing)
        if hasmethod(handler, Tuple{Session, HTTP.Request})
            app = new(handler, session, title, indicator, loading_page)
        elseif hasmethod(handler, Tuple{Session})
            app = new((session, request) -> handler(session), session, title, indicator, loading_page)
        elseif hasmethod(handler, Tuple{HTTP.Request})
            app = new((session, request) -> handler(request), session, title, indicator, loading_page)
        elseif hasmethod(handler, Tuple{})
            app = new((session, request) -> handler(), session, title, indicator, loading_page)
        else
            error("""
            Handler function must have the following signature:
                handler() -> DOM
                handler(session::Session) -> DOM
                handler(request::Request) -> DOM
                handler(session, request) -> DOM
            """)
        end
        finalizer(close, app)
        return app
    end
    function App(dom_object;
            title="Bonito App",
            indicator::Union{Nothing,AbstractConnectionIndicator}=nothing,
            loading_page=nothing,
            threaded=nothing)
        if threaded isa Bool
            @warn "The `threaded` argument is deprecated and has no effect. Each App is run in a thread created by HTTP.jl."
        end
        session = Base.RefValue{Union{Session,Nothing}}(nothing)
        app = new((s, r) -> dom_object, session, title, indicator, loading_page)
        finalizer(close, app)
        return app
    end
end

struct Routes
    routes::Dict{String, App}
end

Routes() = Routes(Dict{String, App}())
Routes(pairs::Pair{String, App}...) = Routes(Dict{String, App}(pairs))
Base.setindex!(routes::Routes, app::App, key::String) = (routes.routes[key] = app)
