using JSServe, Observables, Hyperscript
using JSServe: ES6Module, Asset

some_file = Asset(JSServe.dependency_path("..", "examples", "assets", "julia.png"))

obs = Observable(0)
on(obs) do num
    @show num
end
s = JSServe.HTTPServer.get_server()
close(s)

asset_server = JSServe.HTTPAssetServer()
connection = JSServe.WebSocketConnection()
open("test.html", "w") do io
    global session = Session(connection; asset_server=asset_server)
    app = DOM.div(
        some_file,
        js"""
            const obs = $(obs)
            obs.notify(77)
        """,
        DOM.div(class=Observable("test"))
    )
    domy = JSServe.session_dom(session, app)
    show(io, Hyperscript.Pretty(domy))
end

asset = Asset("test.html")

println("http://localhost:9284", JSServe.url(asset_server, asset))
println("http://localhost:9284", JSServe.url(asset_server, asset))
