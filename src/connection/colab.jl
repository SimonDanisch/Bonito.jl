mutable struct ColabConnection <: Bonito.FrontendConnection
    connection::Bonito.WebSocketConnection
end

ColabConnection() = ColabConnection(Bonito.WebSocketConnection())

Base.isopen(colab::ColabConnection) = isopen(colab.connection)

function Base.write(ws::ColabConnection, binary)
    write(ws.connection, binary)
end

function Base.close(ws::ColabConnection)
    close(ws.connection)
end

function Bonito.setup_connection(session::Session{ColabConnection})
    ws_connection = session.connection.connection
    server = ws_connection.server
    port = server.port
    Bonito.setup_connection(session, ws_connection)
    return js"""
    google.colab.kernel.proxyPort($port).then(proxy_url => {
        $(Bonito.Websocket).then(WS => {
            WS.setup_connection({
                proxy_url: proxy_url,
                session_id: $(session.id),
                compression_enabled: $(session.compression_enabled),
                query: "",
                main_connection: true
            })
        })
    });
    """
end
