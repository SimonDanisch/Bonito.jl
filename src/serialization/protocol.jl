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
const UpdateSession = "12"
const GetSessionDOM = "13"

"""
    process_message(session::Session, bytes::AbstractVector{UInt8})

Handles the incoming websocket messages from the frontend.
Messages are expected to be gzip compressed and packed via MsgPack.
"""
function process_message(session::Session, bytes::AbstractVector{UInt8})
    if session.threadid != Threads.threadid()
        error("process_message should only be called from the same thread as the session")
    end
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
            @debug "Observable $(data["id"]) not found"
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
        if data["exception"] != "nothing"
            exception = JSException(session, data)
            show(stderr, exception)
            session.init_error[] = exception
        else
            sub = get_session(session, data["session"])
            if !isnothing(sub)
                # this may block the connection!
                @async try
                    sub.on_connection_ready(sub)
                catch e
                    @warn "error while processing on_connection_ready" exception = (e, Base.catch_backtrace())
                end
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
    elseif typ == GetSessionDOM
        # this may block the connection!
        @async try
            sub = get_session(session, data["session"])
            if !isnothing(sub)
                app = sub.current_app[]
                if isnothing(app)
                    @warn "requesting dom for uninitialized app"
                else
                    free(sub)
                    session.children[sub.id] = sub
                    empty!(session.session_objects)
                    open!(sub.connection)
                    sub.status = OPEN
                    update_subsession_dom!(sub, data["replace"], app)
                end
            else
                @warn "cant update session is nothing"
            end
        catch e
            @warn "error while processing update App message" exception = (e, Base.catch_backtrace())
        end
    else
        @error "Unrecognized message: $(typ) with type: $(typeof(typ))"
    end
end

function update_subsession_dom!(sub::Session, selector, app::App)
    html = session_dom(sub, app; init=false)
    # We need to manually do the serialization,
    # Since we send it via the parent, but serialization needs to happen
    # for `sub`.
    # sub is not open yet, and only opens if we send the below message for initialization
    # which is why we need to send it via the parent session
    UpdateSession = "12" # msg type
    session_update = Dict(
        "msg_type" => UpdateSession,
        "session_id" => sub.id,
        "messages" => fused_messages!(sub),
        "html" => html,
        "replace" => true,
        "dom_node_selector" => selector
    )
    message = SerializedMessage(sub, session_update)
    send(root_session(sub), message)
    mark_displayed!(sub)
    return sub
end
