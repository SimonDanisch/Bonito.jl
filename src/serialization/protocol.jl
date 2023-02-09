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
            # this is usually non fatal and may happen when old exported HTML gets reconnected
            @debug "Observable $(data["id"]) not found :( "
        else
            # Observable can be wrapped inside Retain
            _obs = obs isa Retain ? obs.value : obs
            Base.invokelatest(update_nocycle!, _obs, data["payload"])
        end
    elseif typ == JavascriptError
        show(stderr, JSException(session, data))
    elseif typ == JavascriptWarning
        @warn "Error in Javascript: $(data["message"])\n)"
    elseif typ == JSDoneLoading
        if !isnothing(data["exception"])
            exception = JSException(session, data)
            show(stderr, exception)
            session.init_error[] = exception
        else
            sub = get_session(session, data["session"])
            if !isnothing(sub)
                sub.on_connection_ready(sub)
            else
                # This can happen for IJulia output after kernel restart,
                # since the loaded html will try to init + connect back
                # TODO, there should be a better way to prevent them from reconnecting
                @debug("Sub session with id $(data["session"]) not found")
            end
        end
    elseif typ == CloseSession
        sub = get_session(session, data["session"])
        if !isnothing(sub)
            if data["subsession"] != "root"
                close(sub)
            else
                # We only empty root sessions, since they will be reused
                @assert root_session(sub) === sub
                empty!(sub)
            end
        else
            @debug("Close request not succesful, can't find sub session with id $(data["session"])")
        end
    elseif typ == PingPong
        # Ping back that pong!!
        send(session, msg_type=PingPong)
    else
        @error "Unrecognized message: $(typ) with type: $(typeof(typ))"
    end
end
