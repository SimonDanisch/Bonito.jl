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

"""
Represent an asset stored at an URL.
We try to always have online & local files for assets
"""
struct Asset
    name::Union{Nothing, String}
    es6module::Bool
    media_type::Symbol
    # We try to always have online & local files for assets
    # If you only give an online resource, we will download it
    # to also be able to host it locally
    online_path::String
    local_path::Union{String, Path}
    bundle_dir::Union{String, Path}
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

struct SerializedMessage
    bytes::Vector{UInt8}
end

@enum SessionStatus UNINITIALIZED RENDERED DISPLAYED OPEN CLOSED

# Very simple and lazy ordered set
# (Don't want to depend on OrderedCollections for something so simple)
struct OrderedSet{T} <: AbstractSet{T}
    items::Vector{T}
end
Base.length(set::OrderedSet) = length(set.items)
Base.iterate(set::OrderedSet) = iterate(set.items)
Base.iterate(set::OrderedSet, state) = iterate(set.items, state)
OrderedSet{T}() where {T} = OrderedSet{T}(T[])
function Base.push!(set::OrderedSet, item)
    (item in set.items) || push!(set.items, item)
end

function Base.union!(set1::OrderedSet, set2)
    union!(set1.items, set2)
end

"""
A web session with a user
"""
mutable struct Session{Connection <: FrontendConnection}
    status::SessionStatus
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
    ignore_message::RefValue{Function}
    imports::OrderedSet{Asset}
    title::String
    compression_enabled::Bool
    deletion_lock::Base.ReentrantLock
    current_app::RefValue{Any}

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
        ) where {Connection}
        session = new{Connection}(
            UNINITIALIZED,
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
            ignore_message,
            imports,
            title,
            compression_enabled,
            Base.ReentrantLock(),
            RefValue{Any}(nothing)
        )
        finalizer(free, session)
        return session
    end
end

struct BinaryAsset
    data::Vector{UInt8}
    mime::String
end
BinaryAsset(session::Session, @nospecialize(data)) = BinaryAsset(SerializedMessage(session, data).bytes, "application/octet-stream")

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
                title="JSServe App",
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
    connection = SubConnection(root)
    session = Session(connection; asset_server=asset_server, on_connection_ready=on_connection_ready, title=title)
    session.parent = parent_session
    parent_session.children[session.id] = session
    return session
end

mutable struct App
    handler::Function
    session::Base.RefValue{Union{Session, Nothing}}
    title::String
    function App(handler::Function;
            title::AbstractString="JSServe App")

        session = Base.RefValue{Union{Session, Nothing}}(nothing)
        if hasmethod(handler, Tuple{Session, HTTP.Request})
            app = new(handler, session, title)
        elseif hasmethod(handler, Tuple{Session})
            app = new((session, request) -> handler(session), session, title)
        elseif hasmethod(handler, Tuple{HTTP.Request})
            app = new((session, request) -> handler(request), session, title)
        elseif hasmethod(handler, Tuple{})
            app = new((session, request) -> handler(), session, title)
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
    function App(dom_object; title="JSServe App")
        session = Base.RefValue{Union{Session,Nothing}}(nothing)
        app = new((s, r) -> dom_object, session, title)
        finalizer(close, app)
        return app
    end
end

struct Routes
    routes::Dict{String, App}
end

Routes() = Routes(Dict{String, App}())

Base.setindex!(routes::Routes, app::App, key::String) = (routes.routes[key] = app)
