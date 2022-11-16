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
        obs = get(session.session_cache, data["id"], nothing)
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
        show(stderr, JSException(data))
    elseif typ == JavascriptWarning
        @warn "Error in Javascript: $(data["message"])\n)"
    elseif typ == JSDoneLoading
        if data["exception"] !== "null"
            exception = JSException(data)
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
            @show data["subsession"]
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
    else
        @error "Unrecognized message: $(typ) with type: $(typeof(typ))"
    end
end

include("sub-connection.jl")
include("websocket.jl")
include("ijulia.jl")
include("no-connection.jl")

function default_connection()
    if isdefined(Main, :IJulia)
        return IJuliaConnection(nothing)
    # elseif isdefined(Main, :Pluto)
        # return PlutoConnection(nothing)
    else
        # return NoConnection()
        return WebSocketConnection()
    end
end

use_parent_session(::Session) = false
use_parent_session(::Session{IJuliaConnection}) = true
use_parent_session(::Session{WebSocketConnection}) = false

const ACTIVE_SESSIONS = Dict{String, Session}()

function look_up_session(id::String)
    if haskey(ACTIVE_SESSIONS, id)
        return ACTIVE_SESSIONS[id]
    else
        error("Unregistered session id: $id. Active sessions: $(collect(keys(ACTIVE_SESSIONS)))")
    end
end

function register_session(session::Session)
    get!(ACTIVE_SESSIONS, session.id, session)
end
