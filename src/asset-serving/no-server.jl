"""
We don't serve files and include anything directly as raw bytes.
Interpolating the same asset many times, will only upload the file to JS one time though.
"""
struct NoServer <: AbstractAssetServer
end
Base.similar(asset::NoServer) = asset # no copy needed

"""
    AssetFolder(folder::String)

Assetserver used to generate files for a statically served site.
"""
mutable struct AssetFolder <: AbstractAssetServer
    folder::String
    current_dir::String # The dir the current html page gets written out to
end

AssetFolder() = AssetFolder("", "")

Base.similar(asset::AssetFolder) = asset # no copy needed


"""
    target_location(assetfolder, asset)

Location, that we will copy the asset to!
"""
function target_location(assetfolder, asset)
    folder = abspath(assetfolder.folder)
    path = abspath(local_path(asset))
    if !occursin(folder, path)
        file = basename(path)
        sub = subdir(asset)
        return normpath(joinpath(folder, "jsserve", sub, file))
    end
    return path
end

target_location(assetfolder, asset::Link) = link.target

function target_location(assetfolder::AssetFolder, asset::BinaryAsset)
    dir = assetfolder.folder
    file = unique_file_key(asset)
    sub = subdir(asset)
    return normpath(joinpath(dir, "jsserve", sub, file))
end

copy_to_assetfolder(assetfolder::AssetFolder, asset::Link) = link.target
function copy_to_assetfolder(assetfolder, asset)
    dir = assetfolder.folder
    path = abspath(local_path(asset))
    if occursin(dir, path)
        return path
    else
        filepath = target_location(assetfolder, asset)
        isdir(dirname(filepath)) || mkpath(dirname(filepath))
        cp(path, filepath; force=true)
        return filepath
    end
end

to_unix_path(path) = replace(path, "\\" => "/")

function relpath_to_assetfolder(assetfolder::AssetFolder, target::String)
    html_dir = to_unix_path(assetfolder.current_dir)
    root_dir = to_unix_path(assetfolder.folder)
    path_to_root = relpath(root_dir, html_dir)
    return path_to_root * target
end

get_target(assetfolder, link::Link) = link.target

function get_target(assetfolder::AssetFolder, asset::Asset)
    root_dir = to_unix_path(assetfolder.folder)
    path = copy_to_assetfolder(assetfolder, asset)
    target_dir = to_unix_path(dirname(path))
    relative = replace(target_dir, root_dir => "")
    return relative * "/" * basename(path)
end

function get_target(assetfolder, asset::BinaryAsset)
    filepath = target_location(assetfolder, asset)
    if !isfile(filepath)
        isdir(dirname(filepath)) || mkpath(dirname(filepath))
        write(filepath, asset.data)
    end
    return get_target(assetfolder, Asset(filepath))
end

url(::NoServer, asset::Asset) = to_data_url(local_path(asset))
url(::NoServer, asset::BinaryAsset) = to_data_url(asset.data, asset.mime)

function url(assetfolder::AssetFolder, asset::AbstractAsset)
    is_online(asset) && return online_path(asset)
    return relpath_to_assetfolder(assetfolder, get_target(assetfolder, asset))
end
