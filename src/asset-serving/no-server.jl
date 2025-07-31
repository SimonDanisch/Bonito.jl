"""
We don't serve files and include anything directly as raw bytes.
Interpolating the same asset many times, will only upload the file to JS one time though.
"""
struct NoServer <: AbstractAssetServer
end
Base.similar(asset::NoServer) = asset # no copy needed

function render_asset(session::Session, ::NoServer, asset::Asset)
    @assert mediatype(asset) in (:css, :js, :mjs) "Found: $(mediatype(asset)))"
    ref = url(session, asset)
    if mediatype(asset) == :js
        if asset.es6module
            return DOM.script("""
                // make sure BONITO_IMPORTS is initialized
                window.BONITO_IMPORTS = window.BONITO_IMPORTS || {};
                BONITO_IMPORTS['$(unique_key(asset))'] =  import('$(ref)');
                """
            )
        else
            return DOM.script(; src=ref)
        end
    elseif mediatype(asset) == :css
        return DOM.link(; href=ref, rel="stylesheet", type="text/css")
    end
end

function import_in_js(io::IO, session::Session, ns::NoServer, asset::Asset)
    if asset.es6module
        push!(session.imports, asset)
        print(io, "BONITO_IMPORTS['$(unique_key(asset))']")
    else
        error("Can only import es6 modules with NoServer right now.")
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
    !isempty(asset.online_path) && return asset.online_path
    return to_data_url(local_path(asset))
end

function url(::NoServer, asset::BinaryAsset)
    return to_data_url(asset.data, asset.mime)
end

abstract type AbstractAssetFolder <: AbstractAssetServer end

mutable struct AssetFolder <: AbstractAssetFolder
    folder::String
    current_dir::String # The dir the current html page gets written out to
end
Base.similar(asset::AssetFolder) = asset # no copy needed

setup_asset_server(::AbstractAssetFolder) = nothing

subdir(asset::Union{BinaryAsset,Asset}) = string(mediatype(asset))

desired_location(assetfolder, asset::Link) = link.target
write_to_assetfolder(assetfolder, asset::Link) = link.target

function desired_location(assetfolder, asset)
    folder = abspath(assetfolder.folder)
    path = abspath(local_path(asset))
    if !occursin(folder, path)
        file = basename(path)
        sub = subdir(asset)
        name, ending = splitext(file)
        h = string(hash(read(path)))
        unique_name = string(name, h, ending)
        filepath = normpath(joinpath(folder, "bonito", sub, unique_name))
        return filepath
    end
    return path
end

function desired_location(assetfolder, asset::BinaryAsset)
    dir = folder(assetfolder)
    file = unique_file_key(asset)
    sub = subdir(asset)
    return normpath(joinpath(dir, "bonito", sub, file))
end

function write_to_assetfolder(assetfolder, asset)
    dir = folder(assetfolder)
    path = abspath(local_path(asset))
    if occursin(dir, path)
        return path
    else
        filepath = desired_location(assetfolder, asset)
        isdir(dirname(filepath)) || mkpath(dirname(filepath))
        cp(path, filepath; force=true)
        return filepath
    end
end

current_dir(assetfolder::AssetFolder) = assetfolder.current_dir
current_dir(assetfolder) = ""

to_unix_path(path) = replace(path, "\\" => "/")

function url(assetfolder::AbstractAssetFolder, asset::Link)
    is_online(asset.target) && return asset.target
    html_dir = to_unix_path(current_dir(assetfolder))
    root_dir = to_unix_path(folder(assetfolder))
    path_to_root = relpath(root_dir, html_dir)
    return to_unix_path(path_to_root * asset.target)
end

function url(assetfolder::AbstractAssetFolder, asset::Asset)
    if !isempty(asset.online_path)
        return asset.online_path
    end
    path = write_to_assetfolder(assetfolder, asset)
    html_dir = to_unix_path(current_dir(assetfolder))
    root_dir = to_unix_path(folder(assetfolder))
    target_dir = to_unix_path(dirname(path))
    relative = replace(target_dir, root_dir => "")
    path_to_root = relpath(root_dir, html_dir)
    patherino = to_unix_path(path_to_root * relative * "/" * basename(path))
    return patherino
end

folder(folder) = folder.folder
folder(assetfolder::AssetFolder) = abspath(assetfolder.folder)

function url(assetfolder::AbstractAssetFolder, asset::BinaryAsset)
    filepath = desired_location(assetfolder, asset)
    if !isfile(filepath)
        isdir(dirname(filepath)) || mkpath(dirname(filepath))
        write(filepath, asset.data)
    end
    return url(assetfolder, Asset(filepath))
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
    return replace(import_path, "\\" => "/")
end

function import_in_js(io::IO, session::Session, assetfolder::DocumenterAssets, asset::Asset)
    if !isempty(asset.online_path)
        import_in_js(io, session, nothing, asset)
        return
    end
    path = url(assetfolder, asset)
    # We write all javascript files into the same folder, so imports inside
    # JSSCode, which get evaled from Bonito.js, should use "./js-dep.js"
    # since the url is relative to the module that imports
    # TODO, is this always called from import? and if not, does it still work?\
    rel_url = "./" * basename(path)
    print(io, "import(new URL('$(rel_url)'), import.meta.url)")
end
