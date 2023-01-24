"""
We don't serve files and include anything directly as raw bytes.
Interpolating the same asset many times, will only upload the file to JS one time though.
"""
struct NoServer <: AbstractAssetServer
    registered_files::Dict{String, String}
end

NoServer() = NoServer(Dict{String, String}())

function import_in_js(io::IO, session::Session, ns::NoServer, asset::Asset)
    if asset == JSServeLib
        # we cheat for JSServe, since lots of dependencies like WebSocket.js can't directly depend on it,
        # but needs to reference it, so we just load `JSServe` with a script tag and put the module into `window.JSServe`
        print(io, "Promise.resolve(window.JSServe)")
    else
        import_key = "JSSERVE_IMPORTS['$(unique_key(asset))']"
        imports = "import($(import_key))"
        str = if !(asset in session.imports)
            # first time something import_define
            import_define = isempty(session.imports) ?  "window.JSSERVE_IMPORTS = {};" : ""
            push!(session.imports, asset)
            "(() => {
                $(import_define)
                $(import_key) = `$(url(ns, asset))`;
                return $(imports);
            })()"
        else
            str = imports
        end
        print(io, str)
    end
end


# This is better for e.g. exporting static sides
# TODO make this more straightforward and easy to customize
# (this gets called/overloaded in js_source.jl)
function inline_code(session::Session, ::NoServer, source::String)
    return DOM.script(src=to_data_url(source, "application/javascript"); type="module")
end


setup_asset_server(::NoServer) = nothing

function url(::NoServer, asset::Asset)
    return to_data_url(local_path(asset))
end

struct AssetFolder <: AbstractAssetServer
    folder::String
end

setup_asset_server(::JSServe.AssetFolder) = nothing

function url(assetfolder::AssetFolder, asset::Asset)
    folder = abspath(assetfolder.folder)
    path = abspath(local_path(asset))
    bundle!(asset)
    if !occursin(folder, path)
        file = basename(path)
        subfolder = if mediatype(asset) == :js
            "javascript/"
        elseif mediatype(asset) == :css
            "css/"
        elseif mediatype(asset) in (:jpeg, :jpg, :png)
            "images/"
        else
            ""
        end
        _path = normpath(joinpath(folder, subfolder * file))
        isdir(dirname(_path)) || mkpath(dirname(_path))
        cp(path, _path; force=true)
        path = _path
    end
    return replace(normpath(relpath(path, folder)), "\\" => "/")
end

function import_in_js(io::IO, session::Session, ::AssetFolder, asset::Asset)
    # Somehow <script src=...> needs to leave out `/`, while import needs to have`/`
    # I guess they resolve the path differently -.-
    print(io, "import('/$(url(session, asset))')")
end
