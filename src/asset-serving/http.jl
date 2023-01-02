mutable struct HTTPAssetServer <: AbstractAssetServer
    registered_files::Dict{String, String}
    server::Server
end

HTTPAssetServer() = HTTPAssetServer(get_server())
HTTPAssetServer(server::Server) = HTTPAssetServer(Dict{String, String}(), server)

function unique_file_key(path::String)
    return bytes2hex(sha1(abspath(path))) * "-" * basename(path)
end

unique_file_key(path) = unique_file_key(string(path))

function url(server::HTTPAssetServer, asset::Asset)
    file = local_path(asset)
    if isempty(file)
        return asset.online_path
    end
    target = normpath(abspath(expanduser(file)))
    key = "/assetserver/" * unique_file_key(target)
    get!(()-> target, server.registered_files, key)
    return JSServe.HTTPServer.online_url(server.server, key)
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
        if isfile(filepath)
            header = ["Access-Control-Allow-Origin" => "*",
                      "Content-Type" => file_mimetype(filepath)]
            return HTTP.Response(200, header, body = read(filepath))
        end
    end
    return HTTP.Response(404)
end

const MATCH_HEX = r"[\da-f]"

function setup_asset_server(asset_server::HTTPAssetServer)
    HTTPServer.route!(asset_server.server, r"/assetserver/" * MATCH_HEX^40 * r"-.*" => asset_server)
    return
end

function HTTPServer.apply_handler(app::App, context)
    server = context.application
    asset_server = HTTPAssetServer(server)
    connection = WebSocketConnection(server)
    session = Session(connection; asset_server=asset_server)
    html_dom = rendered_dom(session, app, context.request)
    html_str = sprint() do io
        page_html(io, session, html_dom)
    end
    return html(html_str)
end
