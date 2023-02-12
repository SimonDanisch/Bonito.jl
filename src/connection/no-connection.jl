struct NoConnection <: FrontendConnection end

function Base.write(connection::NoConnection, data)
    error("Can't communicate with Frontend with no Connection")
end

Base.isopen(::NoConnection) = false
Base.close(::NoConnection) = nothing # nothing to close

setup_connection(session::Session{NoConnection}) = nothing
