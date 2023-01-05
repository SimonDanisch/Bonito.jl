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
    return replace(normpath("/" * relpath(path, folder)), "\\" => "/")
end

# This is better for e.g. exporting static sides
# TODO make this more straightforward and easy to customize
# (this gets called/overloaded in js_source.jl)
function inline_code(session::Session, ::AssetFolder, js::JSCode)
    objects = IdDict()
    # Print code while collecting all interpolated objects in an IdDict
    code = sprint() do io
        print_js_code(io, js, objects)
    end
    if isempty(objects)
        src = code
    else
        # reverse lookup and serialize elements
        interpolated_objects = Dict(v => k for (k, v) in objects)
        data_str = serialize_string(session, interpolated_objects)
        src = """
        // JSCode from $(js.file)
        const data_str = '$(data_str)'
        JSServe.decode_base64_message(data_str).then(objects=> {
            const __lookup_interpolated = (id) => objects[id]
            $code
        })
        """
    end
    return DOM.script(src, type="module")
end
