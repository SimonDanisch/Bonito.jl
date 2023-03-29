"""
We don't serve files and include anything directly as raw bytes.
Interpolating the same asset many times, will only upload the file to JS one time though.
"""
struct NoServer <: AbstractAssetServer
end
Base.similar(asset::NoServer) = asset # no copy needed

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

function url(::NoServer, asset::BinaryAsset)
    return to_data_url(asset.data, asset.mime)
end

abstract type AbstractAssetFolder <: AbstractAssetServer end

struct AssetFolder <: AbstractAssetFolder
    folder::String
end
Base.similar(asset::AssetFolder) = asset # no copy needed

setup_asset_server(::AbstractAssetFolder) = nothing

function write_to_assetfolder(assetfolder, asset)
    folder = abspath(assetfolder.folder)
    path = abspath(local_path(asset))
    if !occursin(folder, path)
        file = basename(path)
        _path = normpath(joinpath(folder, file))
        isdir(dirname(_path)) || mkpath(dirname(_path))
        cp(path, _path; force=true)
        path = _path
    end
    return path
end

function url(assetfolder::AbstractAssetFolder, asset::Asset)
    if !isempty(asset.online_path)
        return asset.online_path
    end
    path = write_to_assetfolder(assetfolder, asset)
    return "/" * replace(normpath(relpath(path, folder(assetfolder))), "\\" => "/")
end

folder(assetfolder::AssetFolder) = abspath(assetfolder.folder)

function url(assetfolder::AbstractAssetFolder, asset::BinaryAsset)
    fname = unique_file_key(asset)
    path = joinpath(folder(assetfolder), fname)
    if !isfile(path)
        write(path, asset.data)
    end
    return url(assetfolder, Asset(path))
end

struct DocumenterAssets <: AbstractAssetFolder
    folder::RefValue{String}
end
Base.similar(asset::DocumenterAssets) = asset # no copy needed

folder(assetfolder::DocumenterAssets) = abspath(assetfolder.folder[])

DocumenterAssets() = DocumenterAssets(RefValue{String}(""))

function url(assetfolder::DocumenterAssets, asset::Asset)
    if !isempty(asset.online_path)
        return asset.online_path
    end
    folder = abspath(assetfolder.folder[])
    path = write_to_assetfolder((; folder=assetfolder.folder[]), asset)
    # TODO, how to properly get the real relative path to assetfolder
    import_path = relpath(path, folder)
    return import_path
end

function import_in_js(io::IO, session::Session, assetfolder::DocumenterAssets, asset::Asset)
    if !isempty(asset.online_path)
        import_in_js(io, session, nothing, asset)
        return
    end
    path = url(assetfolder, asset)
    # We write all javascript files into the same folder, so imports inside
    # JSSCode, which get evaled from JSServe.js, should use "./js-dep.js"
    # since the url is relative to the module that imports
    # TODO, is this always called from import? and if not, does it still work?
    print(io, "import('$("./" * basename(path))')")
end
