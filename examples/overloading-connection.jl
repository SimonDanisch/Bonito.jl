using HTTP, Bonito, Observables
using HTTP.WebSockets: WebSocket, isclosed, receive, send

## Overloading Connection
mutable struct WSConnection <: Bonito.FrontendConnection
    socket::Union{Nothing, WebSocket}
end

# Overload basic function
function Base.write(ws::WSConnection, binary)
    HTTP.WebSockets.send(ws.socket, binary)
end
function Base.close(ws::WSConnection)
    close(ws.socket)
end
Base.isopen(ws::WSConnection) = !isnothing(ws.socket) && !isclosed(ws.socket)

# Setup the julia side of things
function Bonito.setup_connection(session::Session{WSConnection})
    connection = session.connection
    # TODO, just insert a route, or close/reopen webserver
    port = 8083
    url = "127.0.0.1"
    server = WebSockets.listen!(url, port) do websocket
        connection.socket = websocket # once we get the connection, set it!
        while !isclosed(websocket)
            bytes = receive(websocket)
            # process_message works with the bytes serialized by the frontend :)
            Bonito.process_message(session, bytes)
        end
    end

    # Return the javascript you need to set things up
    return js"""
    // Javascript needed to connect to
    const websocket = new WebSocket($("ws://$(url):$(port)"))
    websocket.binaryType = "arraybuffer";
    websocket.onopen = function () {
        console.log("CONNECTED!!");
        websocket.onmessage = function (evt) {
            new Promise(resolve => {
                const binary = new Uint8Array(evt.data);
                Bonito.process_message(Bonito.decode_binary(binary, $(session.compression_enabled)));
                resolve()
            })
        };
        Bonito.on_connection_open((binary_data) => {
            websocket.send(binary_data) // we serialize everything to binary (Uint8Array)
        });
    };
    """
end

# Register your connection
Bonito.register_connection!(WSConnection) do
    # This should REALLY be conditional, otherwise
    # you'll force every package to use your connection per default!
    # See documention of register_connection!
    return WSConnection(nothing)
end


## Overloading Server

struct FileServer <: Bonito.AbstractAssetServer
end

# Nothing really to setup, but if you use e.g. HTTP, this would be the place to insert routes etc
# Have a look at asset-servers/http.jl for more infos about how to implement an HTTP based asset server
Bonito.setup_asset_server(::FileServer) = nothing

function Bonito.url(::FileServer, asset::Bonito.Asset)
    return "file:///" * Bonito.local_path(asset)
end

# Register your file server
Bonito.register_asset_server!(FileServer) do
    return FileServer()
end

# Now, any created session should use your WSConnection!
x = Session()
@assert x.connection isa WSConnection
@assert x.asset_server isa FileServer

Bonito.browser_display() # Show the app in the browser, since e.g. plotpane won't allow to load from file urls
color = Observable("red")
color_css = map(x-> "color: $(x)", color)
App() do session::Session
    Bonito.evaljs(session, js"console.log('hi from JS')")
    return DOM.div("hii"; style=color_css)
end

color[] = "green" # Tadaa, your first div update with your own connection :)
