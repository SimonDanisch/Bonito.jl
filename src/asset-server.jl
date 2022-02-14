const ASSET_REGISTRY = Dict{String, String}()

function unique_file_key(path::String)
    return bytes2hex(sha1(abspath(path))) * "-" * basename(path)
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

include("mimetypes.jl")

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
