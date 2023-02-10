mutable struct HTTPAssetServer <: AbstractAssetServer
    registered_files::Dict{String, Any}
    server::Server
end

HTTPAssetServer() = HTTPAssetServer(get_server())
HTTPAssetServer(server::Server) = HTTPAssetServer(Dict{String, Any}(), server)

function Base.close(server::HTTPAssetServer)
    empty!(server.registered_files)
end

function url(server::HTTPAssetServer, asset::Asset)
    file = local_path(asset)
    isempty(file) && return asset.online_path
    target = normpath(abspath(expanduser(file)))
    key = "/assetserver/" * unique_file_key(target)
    get!(()-> target, server.registered_files, key)
    return JSServe.HTTPServer.online_url(server.server, key)
end

function url(server::HTTPAssetServer, asset::BinaryAsset)
    key = unique_file_key(string(hash(asset.data)))
    filename = "/assetserver/$(key).bin"
    get!(() -> asset, server.registered_files, filename)
    return JSServe.HTTPServer.online_url(server.server, filename)
end

const ASSET_URL_REGEX = r"http://.*/assetserver/([a-z0-9]+-.*?):([\d]+):[\d]+"

function js_to_local_url(server::HTTPAssetServer, url::AbstractString)
    key_regex = r"(/assetserver/[a-z0-9]+-.*?):([\d]+):[\d]+"
    m = match(key_regex, url)
    key = m[1]
    path = server.registered_files[string(key)]
    return path * ":" * m[2]
end

function js_to_local_stacktrace(server::HTTPAssetServer, line::AbstractString)
    function to_url(matched_url)
        js_to_local_url(server, matched_url)
    end
    return replace(line, ASSET_URL_REGEX => to_url)
end

function (server::HTTPAssetServer)(context)
    path = context.request.target
    rf = server.registered_files
    if haskey(rf, path)
        filepath = rf[path]
        if filepath isa BinaryAsset
            header = ["Access-Control-Allow-Origin" => "*",
                "Content-Type" => "application/octet-stream"]
            return HTTP.Response(200, header, body=filepath.data)
        else
            if isfile(filepath)
                header = ["Access-Control-Allow-Origin" => "*",
                    "Content-Type" => file_mimetype(filepath)]
                return HTTP.Response(200, header, body = read(filepath))
            end
        end
    end
    return HTTP.Response(404)
end

const MATCH_HEX = r"[\da-f]"

function setup_asset_server(asset_server::HTTPAssetServer)
    HTTPServer.route!(asset_server.server, r"/assetserver/" * MATCH_HEX^40 * r"-.*" => asset_server)
    return
end
