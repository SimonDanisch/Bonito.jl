Base.close(::AbstractAssetServer) = nothing

include("asset.jl")
include("no-server.jl")
include("http.jl")

"""
    dependency_path(paths...)

Path to serve downloaded dependencies
"""
dependency_path(paths...) = joinpath(@__DIR__, "..", "..", "js_dependencies", paths...)

const JSServeLib = ES6Module(dependency_path("JSServe.js"))
const Websocket = ES6Module(dependency_path("Websocket.js"))
const TailwindCSS = Asset(dependency_path("tailwind.min.css"))
const Styling = Asset(dependency_path("styling.css"))
const MarkdownCSS = Asset(dependency_path("markdown.css"))
