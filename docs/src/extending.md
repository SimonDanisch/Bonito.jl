# Extending JSServe

## Wrapping Javascript frameworks:

```@setup 1
using JSServe
JSServe.Page()
```

```@example 1
leafletjs = JSServe.ES6Module("https://esm.sh/v111/leaflet@1.9.3/es2022/leaflet.js")
leafletcss = JSServe.Asset("https://unpkg.com/leaflet@1.9.3/dist/leaflet.css")
struct LeafletMap
    position::NTuple{2,Float64}
    zoom::Int
end

function JSServe.jsrender(session::Session, map::LeafletMap)

    map_div = DOM.div(id="map"; style="height: 500px;")

    return JSServe.jsrender(session, DOM.div(
        leafletcss,
        leafletjs,
        map_div,
        js"""
            $(leafletjs).then(L=> {
                const map = L.map('map').setView($(map.position), $(map.zoom));
                L.tileLayer(
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
                    maxZoom: 19,
                    attribution: '&copy; <a href="http://www.openstreetmap.org/copyright">OpenStreetMap</a>'
                }).addTo(map);
            })

        """
    ))
end


App() do
    return LeafletMap((51.505, -0.09), 13)
end
```


## Connection




```Julia

struct MyConnection <: JSServe.FrontendConnection
    ...
end

function MyConnection(parent::Session)
    return MyConnection(parent.connection, false)
end

function Base.write(connection::MyConnection, binary)
    write(connection.connection, binary)
end

Base.isopen(connection::MyConnection) = connection.isopen
Base.close(connection::MyConnection) = (connection.isopen = false)
open!(connection::MyConnection) = (connection.isopen = true)

function setup_connection(session::Session{MyConnection})
    return js"""
    // Javascript needed to connect to
    const conn = create_connection(...) // implemented by your framework
    conn.on_msg((msg) => {
        JSServe.process_message(msg)
    });
    // register sending message
    JSServe.on_connection_open((binary) => {
        comm.send(binary)
    }, $(session.compression_enabled));
    """
end
```
