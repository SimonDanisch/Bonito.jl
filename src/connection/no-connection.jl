struct NoConnection <: FrontendConnection end

function Base.write(connection::NoConnection, data)
    error("Can't communicate with Frontend with no Connection")
end

Base.isopen(::NoConnection) = false
Base.close(::NoConnection) = nothing # nothing to close

function setup_connection(session::Session{NoConnection})
    # if we have no connection, we need to ship all send messages
    # as part of the initialization
    messages = fused_messages!(session)
    b64_str = serialize_string(session, messages)
    return js"""
        JSServe.on_connection_open((w)=> null)
        const session_messages = $(b64_str)
        JSServe.decode_base64_message(session_messages).then(JSServe.process_message)
    """
end
