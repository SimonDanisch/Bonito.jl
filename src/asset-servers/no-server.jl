"""
We don't serve files and include anything directly as raw bytes.
Interpolating the same asset many times, will only upload the file to JS one time though.
"""
struct NoServer <: AbstractAssetServer
    registered_files::Dict{String, String}
end

NoServer() = NoServer(Dict{String, String}())

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
    return "/" * relpath(path, folder)
end
