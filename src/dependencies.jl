

mediatype(asset::Asset) = asset.media_type

function Base.show(io::IO, asset::Asset)
    print(io, url(asset))
end

function Asset(online_path::Union{String, Path}; check_isfile=false)
    local_path = ""; real_online_path = ""
    if is_online(online_path)
        local_path = ""
        real_online_path = online_path
    else
        local_path = normalize_path(online_path; check_isfile=check_isfile)
    end
    return Asset(Symbol(getextension(online_path)), real_online_path, local_path)
end


function jsrender(session::Session, asset::Asset)
    register_resource!(session, asset)
    return nothing
end

function local_path(path, serializer)
    if serializer.assetserver
        # we use assetserver, so we register the local file with the server
        return register_local_file(path)
    else
        # we don't use assetserver, so we copy the asset to asset_folder
        # for someone else to serve them!
        if serializer.asset_folder === nothing
            error("Not using assetserver requires to set `asset_folder` to a valid local folder")
        end
        if !isdir(serializer.asset_folder)
            error("`asset_folder` doesn't exist: $(serializer.asset_folder)")
        end
        relative_path = relpath(path, serializer.asset_folder)
        if !(occursin("..", relative_path) || abspath(path) == relative_path)
            # file is already in asset folder
            return relative_path
        else
            path_base = dirname(path)
            file_name = basename(path)
            unique_file_name = unique_name_in_folder(serializer.asset_folder, file_name)
            unique_path = joinpath(serializer.asset_folder, unique_file_name)
            cp(path, unique_path, force=true)
            return unique_file_name
        end
    end
end

const JSServeLib = ES6Module("./JSServe.js")
const MarkdownCSS = Asset(dependency_path("markdown.css"))
const TailwindCSS = Asset(dependency_path("tailwind.min.css"))
const Styling = Asset(dependency_path("styled.css"))
