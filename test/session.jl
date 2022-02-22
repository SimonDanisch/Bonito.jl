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
obs = Observable(0)
app = DOM.div(
    some_file,
    js"""
        (async function (){
            const Test = await $(test_mod)
            console.log(Test)
            Test.hello()
            const obs = $(obs)
            console.log(obs)
            obs.on(x=> console.log('update: ' + x))
            obs.notify(1)
        })()

    """,
    DOM.div(class=Observable("test"))
)
open("test.html", "w") do io
    s = Session(; asset_server=JSServe.HTTPAssetServer())
    domy = JSServe.session_dom(s, app)
    show(io, Hyperscript.Pretty(domy))
end
