using JSServe, Observables, Hyperscript
using JSServe: ES6Module, Asset
using Deno_jll

path = JSServe.dependency_path("JSServe.js")
bundled = joinpath(dirname(path), "JSServe.bundle.js")
Deno_jll.deno() do exe
    write(bundled, read(`$exe bundle $(path)`))
end

test_mod = ES6Module(JSServe.dependency_path("Test.js"))
some_file = Asset(JSServe.dependency_path("..", "examples", "assets", "julia.png"))
Websocket = ES6Module(JSServe.dependency_path("Websocket.js"))

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
            (async () => {
                const Websocket = await $(Websocket)
                Websocket.setup_connection({proxy_url: '', session_id: $(session.id)})
                const obs = $(obs)
                obs.notify(77)
            })()

        """,
        DOM.div(class=Observable("test"))
    )
    domy = JSServe.session_dom(session, app)
    show(io, Hyperscript.Pretty(domy))
end

asset = Asset("test.html")

println("http://localhost:9284", JSServe.url(asset_server, asset))
println("http://localhost:9284", JSServe.url(asset_server, asset))
