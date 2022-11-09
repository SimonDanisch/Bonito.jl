struct HTTPAssetServer <: AbstractAssetServer
    registered_files::Dict{String, String}
end

HTTPAssetServer() = HTTPAssetServer(Dict{String, String}())

function url(server::HTTPAssetServer, asset::Asset)
    file = local_path(asset)
    target = normpath(abspath(expanduser(file)))
    key = "/assetserver/" * unique_file_key(target)
    get!(()-> target, server.registered_files, key)
    return key
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
    server = HTTPServer.get_server()
    HTTPServer.route!(server, r"/assetserver/" * MATCH_HEX^40 * r"-.*" => asset_server)
    return
end

function apply_handler(app::App, context)
    server = context.application
    session = insert_session!(server)
    html_dom = Base.invokelatest(app.handler, session, context.request)
    return html(page_html(session, html_dom))
end
