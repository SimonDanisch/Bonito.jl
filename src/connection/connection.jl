# Save some bytes by using ints for switch variable
const UpdateObservable = "0"
const OnjsCallback = "1"
const EvalJavascript = "2"
const JavascriptError = "3"
const JavascriptWarning = "4"
const RegisterObservable = "5"
const JSDoneLoading = "8"
const FusedMessage = "9"

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
        obs = session.observables[data["id"]]
        Base.invokelatest(update_nocycle!, obs, data["payload"])
    elseif typ == JavascriptError
        show(stderr, JSException(data))
    elseif typ == JavascriptWarning
        @warn "Error in Javascript: $(data["message"])\n)"
    elseif typ == JSDoneLoading
        if data["exception"] !== "null"
            exception = JSException(data)
            show(stderr, exception)
            session.init_error[] = exception
        end
        session.on_connection_ready(session)
    else
        @error "Unrecognized message: $(typ) with type: $(typeof(typ))"
    end
end

include("websocket.jl")
include("ijulia.jl")
include("no-connection.jl")

function default_connect()
    if isdefined(Main, :IJulia)
        return IJuliaConnection(nothing)
    # elseif isdefined(Main, :Pluto)
        # return PlutoConnection(nothing)
    else
        return NoConnection()
        # return WebSocketConnection(nothing)
    end
end

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
