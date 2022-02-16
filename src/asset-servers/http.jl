struct HTTPAssetServer <: AbstractAssetServer
    registered_files::Dict{String, String}
end

function register_local_file(file::String)
    target = normpath(abspath(expanduser(file)))
    key = "/assetserver/" * unique_file_key(target)
    get!(()-> target, ASSET_REGISTRY, key)
    return key
end

function is_key_registered(key::String)
    return haskey(ASSET_REGISTRY, key)
end

function assetserver_to_localfile(key::String)
    path = get(ASSET_REGISTRY, key, nothing)
    if path === nothing
        error("Key does not map to a local path (is not registered via `register_local_file`): $(key)")
    end
    return path
end

function file_server(context)
    path = context.request.target
    if is_key_registered(path)
        filepath = assetserver_to_localfile(path)
        if isfile(filepath)
            header = ["Access-Control-Allow-Origin" => "*",
                      "Content-Type" => file_mimetype(filepath)]
            return HTTP.Response(200, header, body = read(filepath))
        end
    end
    return HTTP.Response(404)
end

function module_server(context)
    path = context.request.target[2:end]
    dir = string(dependency_path())
    file = joinpath(dir, path)
    if isfile(file)
        header = ["Access-Control-Allow-Origin" => "*",
                    "Content-Type" => "application/javascript"]
        return HTTP.Response(200, header, body = read(file))
    end
    return HTTP.Response(404)
end
