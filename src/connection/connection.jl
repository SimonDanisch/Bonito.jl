
"""
# Inteface for FrontendConnection

Inherit from FrontendConnection
```julia
struct MyConnection <: FrontendConnection
end
```

Needs to have a constructor with 0 arguments:
```julia
MyConnection()
```

Needs to overload `Base.write` for sending binary data
```julia
Base.write(connection::MyConnection, bytes::AbstractVector{UInt8})
```

Needs to implement isopen to indicate status of connection
```julia
Base.isopen(c::MyConnection)
```

Setup connection will be called before rendering any dom with `session`.
The return value will be inserted into the DOM of the rendered App and can be used to
do the JS part of opening the connection.
```julia
JSServe.setup_connection(session::Session{IJuliaConnection})::Union{JSCode, Nothing}
```

One can overload `use_parent_session`, to turn on rendering dom objects inside sub-sessions while keeping one parent session
managing the connection alive.
This is handy for IJulia/Pluto, since the parent session just needs to be initialized one time and can stay active and globally store objects used multiple times across doms.
```Julia
JSServe.use_parent_session(::Session{MyConnection}) = false/false
```
"""

# Save some bytes by using ints for switch variable
const UpdateObservable = "0"
const OnjsCallback = "1"
const EvalJavascript = "2"
const JavascriptError = "3"
const JavascriptWarning = "4"
const RegisterObservable = "5"
const JSDoneLoading = "8"
const FusedMessage = "9"
const CloseSession = "10"
const PingPong = "11"


function get_session(session::Session, id::String)
    session.id == id && return session
    if haskey(session.children, id)
        return session.children[id]
    end
    # recurse
    for (key, sub) in session.children
        s = get_session(sub, id)
        isnothing(s) || return s
    end
    # Nothing found...
    return nothing
end

"""
    process_message(session::Session, bytes::AbstractVector{UInt8})

Handles the incoming websocket messages from the frontend.
Messages are expected to be gzip compressed and packed via MsgPack.
"""
function process_message(session::Session, bytes::AbstractVector{UInt8})
    if isempty(bytes)
        @warn "empty message received from frontend"
        return
    end
    data = deserialize_binary(bytes)
    typ = data["msg_type"]
    if typ == UpdateObservable
        obs = get(session.session_objects, data["id"], nothing)
        if isnothing(obs)
            @warn "Observable $(data["id"]) not found :( "
        else
            if obs isa Retain
                Base.invokelatest(update_nocycle!, obs.value, data["payload"])
            else
                Base.invokelatest(update_nocycle!, obs, data["payload"])
            end
        end
    elseif typ == JavascriptError
        show(stderr, JSException(session, data))
    elseif typ == JavascriptWarning
        @warn "Error in Javascript: $(data["message"])\n)"
    elseif typ == JSDoneLoading
        if data["exception"] !== "null"
            exception = JSException(session, data)
            show(stderr, exception)
            session.init_error[] = exception
        else
            sub = get_session(session, data["session"])
            if !isnothing(sub)
                sub.on_connection_ready(sub)
            else
                error("Sub session with id $(data["session"]) not found")
            end
        end
    elseif typ == CloseSession
        sub = get_session(session, data["session"])
        if !isnothing(sub)
            if data["subsession"] != "root"
                println("closing $(sub.id)")
                close(sub)
            else
                # We only empty root sessions, since they will be reused
                println("empty root!")
                @assert root_session(sub) === sub
                empty!(sub)
            end
        else
            error("Sub session with id $(data["session"]) not found")
        end
    elseif typ == PingPong
        # Ping back that pong!!
        send(session, msg_type=PingPong)
    else
        @error "Unrecognized message: $(typ) with type: $(typeof(typ))"
    end
end

include("sub-connection.jl")
include("websocket.jl")
include("ijulia.jl")
include("pluto.jl")
include("no-connection.jl")

const AVAILABLE_CONNECTIONS = Pair{DataType, Function}[]

"""
    register_connection!(condition::Function, ::Type{<: FrontendConnection})

Registers a new Connection type.

condition is a function that should return `nothing`, if the connection type shouldn't be used, and an initialized Connection, if the conditions are right.
E.g. The IJulia connection should only be used inside an IJulia notebook so it's registered like this:
```julia
register_connection!(IJuliaConnection) do
    if isdefined(Main, :IJulia)
        return IJuliaConnection()
    end
    return nothing
end
```
The last connection registered take priority, so if you register a new connection last in your Package, and always return it,
You will overwrite the connection type for any other package.
If you want to force usage temporary, try:
```julia
force_connection(YourConnectionType()) do
    ...
end
# which is the same as:
force_connection!(YourConnectionType())
...
force_connection!()
```
"""
function register_connection!(condition::Function, ::Type{C}) where C <: FrontendConnection
    register_type!(condition, C, AVAILABLE_CONNECTIONS)
    return
end

const FORCED_CONNECTION = Base.RefValue{Union{Nothing, FrontendConnection}}(nothing)

function force_connection!(conn::Union{Nothing, FrontendConnection}=nothing)
    force_type!(conn, FORCED_CONNECTION)
end

function force_connection(f, conn::Union{Nothing, FrontendConnection})
    force_type(f, conn, FORCED_CONNECTION)
end

# Websocket is the fallback, so it's registered first (lower priority),
# and never returns nothing
register_connection!(WebSocketConnection) do
    return WebSocketConnection()
end

register_connection!(IJuliaConnection) do
    isdefined(Main, :IJulia) && IJuliaConnection()
    return nothing
end

register_connection!(PlutoConnection) do
    isdefined(Main, :PlutoRunner) && return PlutoConnection()
    return nothing
end

function default_connection()
    if !isnothing(FORCED_CONNECTION[])
        return FORCED_CONNECTION[]
    else
        ac = AVAILABLE_CONNECTIONS
        for i in length(ac):-1:1 # start from last inserted
            conn_or_nothing = ac[i][2]()::Union{FrontendConnection, Nothing}
            isnothing(conn_or_nothing) || return conn_or_nothing
        end
        error("No connection found. This can only happen if someone messed with `JSServe.AVAILABLE_CONNECTIONS`")
    end
end

use_parent_session(::Session) = false
use_parent_session(::Session{IJuliaConnection}) = true
use_parent_session(::Session{PlutoConnection}) = true
use_parent_session(::Session{WebSocketConnection}) = false

# Global session lookup, for e.g. websocket connection, or HTTP Apps
const ACTIVE_SESSIONS = Dict{String, Session}()

function look_up_session(id::String)
    if haskey(ACTIVE_SESSIONS, id)
        return ACTIVE_SESSIONS[id]
    else
        error("Unregistered session id: $id. Active sessions: $(collect(keys(ACTIVE_SESSIONS)))")
    end
end

function register_session!(session::Session)
    get!(ACTIVE_SESSIONS, session.id, session)
end

function unregister_session!(session::Session)
    delete!(ACTIVE_SESSIONS, session.id)
end
