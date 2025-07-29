const PLUTO_PKG_ID = Base.PkgId(Base.UUID("c3e4b0f8-55cb-11ea-2926-15256bba5781"), "Pluto")

mutable struct PlutoConnection <: FrontendConnection
    connection::WebSocketConnection
end

PlutoConnection() = PlutoConnection(WebSocketConnection())

Base.isopen(pluto::PlutoConnection) = isopen(pluto.connection)

function Base.write(ws::PlutoConnection, binary::AbstractVector{UInt8})
    write(ws.connection, binary)
end

function Base.close(ws::PlutoConnection)
    close(ws.connection)
end

function setup_connection(session::Session{PlutoConnection})
    return setup_connection(session, session.connection.connection)
end
