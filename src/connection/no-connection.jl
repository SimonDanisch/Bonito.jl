struct NoConnection <: FrontendConnection end

function Base.write(connection::NoConnection, data::AbstractVector{UInt8})
    error("Can't communicate with Frontend with no Connection")
end

Base.isopen(::NoConnection) = false
Base.close(::NoConnection) = nothing # nothing to close

function setup_connection(session::Session{NoConnection})
    # Notify JavaScript that this is a no-connection session
    # so the indicator can show the appropriate status
    return js"""
    if (typeof Bonito !== 'undefined' && Bonito.set_no_connection) {
        Bonito.set_no_connection();
    }
    """
end
