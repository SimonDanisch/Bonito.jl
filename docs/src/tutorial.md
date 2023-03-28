# Tutorial

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
