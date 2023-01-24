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



abstract type AbstractAssetFolder <: AbstractAssetServer end

struct AssetFolder <: AbstractAssetFolder
    folder::String
end

setup_asset_server(::AbstractAssetFolder) = nothing

function write_to_assetfolder(assetfolder, asset)
    folder = abspath(assetfolder.folder)
    path = abspath(local_path(asset))
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

function url(assetfolder::AbstractAssetFolder, asset::Asset)
    return write_to_assetfolder(assetfolder, asset)
end

function import_in_js(io::IO, session::Session, ::AssetFolder, asset::Asset)
    print(io, "import('$(url(session, asset))')")
end

struct DocumenterAssets <: AbstractAssetFolder
    folder::RefValue{String}
end

DocumenterAssets() = DocumenterAssets(RefValue{String}(""))

function import_in_js(io::IO, session::Session, assetfolder::DocumenterAssets, asset::Asset)
    url = write_to_assetfolder((; folder=assetfolder.folder[]), asset)
    # We write all javascript files into the same folder, so imports inside
    # JSSCode, which get evaled from JSServe.js, should use "./js-dep.js"
    # since the url is relative to the module that imports
    # TODO, is this always called from import? and if not, does it still work?
    print(io, "import('$("./" * basename(url))')")
end

function url(assetfolder::DocumenterAssets, asset::Asset)
    # TODO, how to properly get the real relative path to assetfolder
    return write_to_assetfolder((; folder=assetfolder.folder[]), asset)
end
