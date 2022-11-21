mutable struct HTTPAssetServer <: AbstractAssetServer
    registered_files::Dict{String, String}
    server
end

HTTPAssetServer() = HTTPAssetServer(Dict{String, String}(), nothing)
HTTPAssetServer(server::Server) = HTTPAssetServer(Dict{String, String}(), server)

function url(server::HTTPAssetServer, asset::Asset)
    file = local_path(asset)
    target = normpath(abspath(expanduser(file)))
    key = "/assetserver/" * unique_file_key(target)
    get!(()-> target, server.registered_files, key)
    return JSServe.HTTPServer.online_url(server.server, key)
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

function setup_asset_server(asset_server::HTTPAssetServer)
    if isnothing(asset_server.server)
        asset_server.server = HTTPServer.get_server()
    end
    HTTPServer.route!(asset_server.server, r"/assetserver/" * MATCH_HEX^40 * r"-.*" => asset_server)
    return
end

function HTTPServer.apply_handler(app::App, context)
    server = context.application
    asset_server = HTTPAssetServer(server)
    connection = WebSocketConnection(server)
    session = Session(connection; asset_server=asset_server)
    register_session!(session)
    html_dom = Base.invokelatest(app.handler, session, context.request)
    html_str = sprint() do io
        page_html(io, session, jsrender(session, html_dom))
    end
    return html(html_str)
end
