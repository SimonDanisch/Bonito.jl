mutable struct HTTPAssetServer <: AbstractAssetServer
    registered_files::Dict{String, Any}
    server::Server
end

const MATCH_HEX = r"[\da-f]"
const ASSET_ROUTE_REGEX = r"assets-(?:\d+){20}"
const UNIQUE_FILE_KEY_REGEX = MATCH_HEX^40 * r"-.*"
const ASSET_URL_REGEX = "/" * ASSET_ROUTE_REGEX * "/" * UNIQUE_FILE_KEY_REGEX
const WHOLE_URL_REGEX = r"http://.*" * ASSET_URL_REGEX

server_key(server::HTTPAssetServer) = "/assets-$(hash(server))/"
route_key(server::HTTPAssetServer) = server_key(server) * UNIQUE_FILE_KEY_REGEX

HTTPAssetServer() = HTTPAssetServer(get_server())
HTTPAssetServer(server::Server) = HTTPAssetServer(Dict{String, Any}(), server)

Base.similar(s::HTTPAssetServer) = HTTPAssetServer(s.server)

function Base.close(server::HTTPAssetServer)
    HTTPServer.delete_route!(server.server, route_key(server))
    empty!(server.registered_files)
end

function url(server::HTTPAssetServer, asset::Asset)
    file = local_path(asset)
    isempty(file) && return asset.online_path
    target = normpath(abspath(expanduser(file)))
    key = server_key(server) * unique_file_key(target)
    get!(()-> target, server.registered_files, key)
    return JSServe.HTTPServer.online_url(server.server, key)
end

function url(server::HTTPAssetServer, asset::BinaryAsset)
    filename = unique_file_key(asset)
    key = server_key(server) * filename
    get!(() -> asset, server.registered_files, key)
    return JSServe.HTTPServer.online_url(server.server, key)
end

function js_to_local_url(server::HTTPAssetServer, url::AbstractString)
    m = match(ASSET_URL_REGEX, url)
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

function setup_asset_server(server::HTTPAssetServer)
    HTTPServer.route!(server.server, route_key(server) => server)
    return
end
