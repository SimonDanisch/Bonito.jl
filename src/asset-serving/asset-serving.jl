Base.close(::AbstractAssetServer) = nothing
setup_asset_server(::AbstractAssetServer) = nothing

subdir(asset::AbstractAsset) = string(mediatype(asset))

include("asset.jl")
include("no-server.jl")
include("http.jl")

# This is better for e.g. exporting static sides
# TODO make this more straightforward and easy to customize
# (this gets called/overloaded in js_source.jl)
function inline_code(session::Session, ::NoServer, source::String)
    return DOM.script(src=to_data_url(source, "application/javascript"); type="module")
end

# This works better with Pluto, which doesn't allow <script> the script </script>
# and only allows `<script src=url>  </script>`
# TODO, NoServer is kind of misussed here, since Pluto happens to use it
# I guess the best solution would be a trait system or some other config object
# for deciding how to inline code into pure HTML
function inline_code(session::Session, noserver, source::String)
    return DOM.script(source; type="module")
end

function import_in_js(io::IO, session::Session, asset_server, asset::BinaryAsset)
    print(io, "JSServe.fetch_binary('$(url(session, asset))')")
end

function import_in_js(io::IO, session::Session, asset_server, asset::AbstractAsset)
    ref = url(session, asset)
    if is_es6module(asset)
        print(io, "import('$(ref)')")
    else
        print(io, "JSServe.fetch_binary($(ref))")
    end
end

function import_in_js(io::IO, session::Session, ns::NoServer, asset::Asset)
    import_key = "JSSERVE_IMPORTS['$(unique_key(asset))']"
    if asset.es6module
        imports = "import($(import_key))"
    else
        imports = "JSServe.fetch_binary($(import_key))"
    end
    # first time we import this asset, we need to add it to the imports!
    str = if !(asset in session.imports)
        push!(session.imports, asset)
        "(() => {
            if (!window.JSSERVE_IMPORTS) {
                window.JSSERVE_IMPORTS = {};
            }
            $(import_key) = `$(url(ns, asset))`;
            return $(imports);
        })()"
    else
        str = imports
    end
    print(io, str)
end


"""
    dependency_path(paths...)

Path to serve downloaded dependencies
"""
dependency_path(paths...) = normpath(joinpath(@__DIR__, "..", "..", "js_dependencies", paths...))

const JSServeLib = ES6Module(dependency_path("JSServe.js"))
const Websocket = ES6Module(dependency_path("Websocket.js"))
const Styling = Asset(dependency_path("styling.css"))
const MarkdownCSS = Asset(dependency_path("markdown.css"))

struct Tailwind <: AbstractAsset
end
const TailwindCSS = Tailwind()
mediatype(::Tailwind) = :css

function render_asset(session::Session, ::Tailwind)
    if session.asset_server isa AssetFolder
        # For AssetFolder, we assume one is creating a statically served website,
        # Which we create an optimized build for
        ref = url(session, Link("/jsserve/css/tailwind.css"))
        return DOM.link(href=ref, rel="stylesheet", type="text/css")
    else
        # In "development" mode just use the tailwind script from CDN
        return DOM.script(src="https://cdn.tailwindcss.com/3.3.1")
    end
end

# Lightweight Require.jl for NodeJS
const NODEJS_PKG_ID = Base.PkgId(Base.UUID("2bd173c7-0d6d-553b-b6af-13a54713934c"), "NodeJS")
function NodeJS()
    if haskey(Base.loaded_modules, NODEJS_PKG_ID)
        return Base.loaded_modules[NODEJS_PKG_ID]
    else
        return nothing
    end
end

function npm(cmd)
    Node = NodeJS(); isnothing(Node) && error("Can't use NPM without `using NodeJS`")
    path_sep = Sys.iswindows() ? ";" : ":"
    path_with_node = dirname(Node.node_executable_path) * path_sep * ENV["PATH"]
    run(setenv(`$(Node.npm_cmd()) $cmd`, Dict("PATH" => path_with_node)))
end

function generate_tailwind_css(Node, html_dir, css_file; config = nothing)
    if isnothing(config)
        config = js"""
        module.exports = {
            content: ["./**/*.html"],
        }
        """
    end
    config_path = joinpath(html_dir, "tailwind.config.js")
    open(io -> print(io, config), config_path, "w")
    cd(html_dir) do
        npm(`install tailwindcss`)
        npm(`exec -- tailwindcss -o $(css_file) --minify`)
    end
end
function jsrender(session::Session, tw::Tailwind)
    push!(session.imports, tw)
    return nothing
end

function post_export_hook(routes::Routes, folder::AssetFolder, ::Tailwind)
    Node = NodeJS()
    # create asset in some random folder, just to use the AssetFolder interface to get the path the asset would be copied to
    css_file = target_location(folder, Asset(joinpath(@__DIR__, "tailwind.css")))
    if !isnothing(Node)
        generate_tailwind_css(Node, folder.folder, css_file)
    else
        @warn("Add and run `using NodeJS` to use TailwindCSS in your website with an optimized build. Falling back to non optimized build!")
        cp(dependency_path("tailwind-fallback.min.css"), css_file; force=true)
    end
end
