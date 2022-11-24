
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

function default_connection()
    if isdefined(Main, :IJulia)
        return IJuliaConnection()
    elseif isdefined(Main, :PlutoRunner)
        return PlutoConnection()
    else
        return WebSocketConnection()
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
