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
    connect = setup_connection(session, session.connection.connection)
    # Pluto's static HTML export replays the outputs verbatim, so this runs there
    # too. An export must not connect (it would attach to the live notebook's
    # session, or retry for 30 s against a gone process); it marks itself with
    # `window.pluto_disable_ui`, so treat such a page as offline.
    return js"""
        if (typeof currentScript !== 'undefined' && currentScript.closest("pluto-editor.disable_ui") != null) {
            Bonito.set_no_connection();
        } else {
            $(connect)
        }
    """
end
