using JSServe, Observables
using JSServe: ES6Module, Asset

JSServeLib = ES6Module(JSServe.dependency_path("JSServe.js"))
test_mod = ES6Module(JSServe.dependency_path("Test.js"))
some_file = Asset(JSServe.dependency_path("..", "examples", "assets", "julia.png"))
obs = Observable(0)
s = Session()

begin
    path = joinpath(@__DIR__, "..", "js_dependencies", "JSServe.bundled.js")
    isfile(path) && rm(path)
    domy = DOM.div(
        # some_file,
        JSServeLib,
        js"""
            const Test = $(test_mod)
            console.log(Test)
            Test.hello()
            const obs = $(obs)
            console.log(obs)
        """,
        DOM.div(class=Observable("test"))
    )

    open("test.html", "w") do io
        show(io, JSServe.jsrender(s,domy))
    end
end

js_str = js"""
// this will result in importing jsmodule
// Doing this in many places will only import jsmodule once
const {the, funcs, you, want} = $(test_mod)
const {other_func} = $(test_mod)
// This will give you the raw bytes as a Uint8Array
const raw_file_bytes = $(test_mod)
"""

s = Session()

x = JSServe.serialize_cached(s, js_str);

js_str_2 = js"""
const {meow} = $(jsmodule)
"""

x = JSServe.serialize_cached(s, [jsmodule, jsmodule]);

bytes = JSServe.MsgPack.pack(x)

obs = Observable(22)
js_str = js"""
const obs = $(obs)
"""

msg = Dict(:msg_type => JSServe.EvalJavascript, :payload => "test")
x = JSServe.serialize_cached(s, msg);

App() do
    DOM.div("hi", js"console.log('hehehe')")
end
