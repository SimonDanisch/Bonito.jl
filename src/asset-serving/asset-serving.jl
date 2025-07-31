Base.close(::AbstractAssetServer) = nothing

include("asset.jl")
include("no-server.jl")
include("http.jl")

function import_js(asset_server::Union{HTTPAssetServer, ChildAssetServer}, asset::Asset)
    return "'$(url(asset_server, asset))'"
end

function import_js(asset_server::AbstractAssetServer, asset::Asset)
    ref = url(asset_server, asset)
    if startswith(ref, ".")
        ref = ref[2:end]
    end
    return "new URL('../$(ref)', window.location.href).href"
end

const JS_DEPENDENCIES = joinpath(@__DIR__, "..", "..", "js_dependencies")

"""
    dependency_path(paths...)

Path to serve downloaded dependencies
"""
dependency_path(paths...) = joinpath(JS_DEPENDENCIES, paths...)

const BonitoLib = ES6Module(dependency_path("Bonito.js"))
const Websocket = ES6Module(dependency_path("Websocket.js"))
const Styling = Asset(dependency_path("styling.css"))
const MarkdownCSS = Asset(dependency_path("markdown.css"))
const TailwindCSS = Asset("https://cdn.tailwindcss.com/3.3.1"; mediatype=:js) # For Development
