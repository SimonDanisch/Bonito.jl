using JSServe, Observables, Hyperscript
using JSServe: ES6Module, Asset

some_file = Asset(JSServe.dependency_path("..", "examples", "assets", "julia.png"))

obs = Observable(0)
on(obs) do num
    @show num
end

App() do session
    return DOM.div(
        some_file,
        js"""
            const obs = $(obs)
            obs.notify(77)
        """,
        DOM.div(class=Observable("test"))
    )
end

using WGLMakie

scatter(1:4)
