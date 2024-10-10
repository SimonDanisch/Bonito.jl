Base.close(::AbstractAssetServer) = nothing

include("asset.jl")
include("no-server.jl")
include("http.jl")

const JS_DEPENDENCIES = @path joinpath(@__DIR__, "..", "..", "js_dependencies")

"""
    dependency_path(paths...)

Path to serve downloaded dependencies
"""
dependency_path(paths...) = @path joinpath(JS_DEPENDENCIES, paths...)

const BonitoLib = ES6Module(dependency_path("Bonito.js"))
const Websocket = ES6Module(dependency_path("Websocket.js"))
const Styling = Asset(dependency_path("styling.css"))
const MarkdownCSS = Asset(dependency_path("markdown.css"))
const TailwindCSS = Asset("https://cdn.tailwindcss.com/3.3.1"; mediatype=:js) # For Development
