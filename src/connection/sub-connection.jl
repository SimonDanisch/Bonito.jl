

function SubConnection(parent::Session)
    return SubConnection(parent.connection, false)
end

function Base.write(connection::SubConnection, binary)
    write(connection.connection, binary)
end

Base.isopen(connection::SubConnection) = connection.isopen
Base.close(connection::SubConnection) = (connection.isopen = false)
open!(connection::SubConnection) = (connection.isopen = true)

function setup_connection(session::Session{SubConnection})
    parent_connection = session.connection.connection
    # Ugh, special case for no connection, since we dont inline the setup code... Maybe we should just always do that
    if parent_connection isa NoConnection
        messages = fused_messages!(session)
        b64_str = serialize_string(session, messages)
        return js"""
            JSServe.on_connection_open((w)=> null)
            const session_messages = $(b64_str)
            JSServe.decode_base64_message(session_messages).then(JSServe.process_message)
        """
    else
        return nothing
    end
end
