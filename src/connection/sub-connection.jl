

function SubConnection(parent::Session)
    return SubConnection(parent.connection, false)
end

function Base.write(connection::SubConnection, msg::SerializedMessage)
    write(connection.connection, msg)
end

function Base.write(connection::SubConnection, binary::AbstractVector{UInt8})
    write(connection.connection, binary)
end

Base.isopen(connection::SubConnection) = connection.isopen
Base.close(connection::SubConnection) = (connection.isopen = false)
open!(connection::SubConnection) = (connection.isopen = true)

setup_connection(::Session{SubConnection}) = nothing
