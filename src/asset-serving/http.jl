using .HTTPServer: has_route, get_route, route!

mutable struct HTTPAssetServer <: AbstractAssetServer
    # Reference count the files/binary assets, so we can clean them up for child sessions
    registered_files::Dict{String,Tuple{Set{UInt},Union{String, BinaryAsset}}}
    server::Server
    lock::ReentrantLock
end

mutable struct ChildAssetServer <: AbstractAssetServer
    parent::HTTPAssetServer
end

const MATCH_HEX = r"[\da-f]"
const ASSET_ROUTE_REGEX = r"assets-(?:\d+){20}"
const UNIQUE_FILE_KEY_REGEX = MATCH_HEX^40 * r"-.*"
const ASSET_URL_REGEX = "/" * ASSET_ROUTE_REGEX * "/" * UNIQUE_FILE_KEY_REGEX
const HTTP_ASSET_ROUTE_KEY = "/assets/" * UNIQUE_FILE_KEY_REGEX

HTTPAssetServer() = HTTPAssetServer(get_server())

function HTTPAssetServer(server::Server)
    key = HTTP_ASSET_ROUTE_KEY
    lock(server.routes.lock) do
        if has_route(server.routes, key)
            return ChildAssetServer(get_route(server.routes, key))
        else
            http = HTTPAssetServer(Dict{String,Tuple{Set{UInt},AbstractAsset}}(), server, ReentrantLock())
            route!(server, HTTP_ASSET_ROUTE_KEY => http)
            return ChildAssetServer(http)
        end
    end
end

Base.similar(s::HTTPAssetServer) = ChildAssetServer(s)
Base.similar(s::ChildAssetServer) = ChildAssetServer(s.parent)

function Base.close(server::HTTPAssetServer)
    @debug "Closing HTTPAssetServer"
    HTTPServer.delete_route!(server.server, HTTP_ASSET_ROUTE_KEY)
    empty!(server.registered_files)
end

function Base.close(server::ChildAssetServer)
    lock(server.parent.lock) do
        id = objectid(server)
        to_delete = Set{String}()
        reg_files = server.parent.registered_files
        for (key, (refs, _)) in reg_files
            delete!(refs, id)
            isempty(refs) && push!(to_delete, key)
        end
        foreach(key -> delete!(reg_files, key), to_delete)
    end
end

serving_target(asset::Asset) = normpath(abspath(expanduser(local_path(asset))))
serving_target(asset::AbstractAsset) = asset

function refs_and_url(server, asset::AbstractAsset)
    key = "/assets/" * unique_file_key(asset)
    refs, target = get!(()-> (Set{UInt}(), serving_target(asset)), server.registered_files, key)
    return refs, HTTPServer.online_url(server.server, key)
end

function url(server::HTTPAssetServer, asset::AbstractAsset)
    is_online(asset) && return online_path(asset)
    lock(server.lock) do
        return refs_and_url(server, asset)[2]
    end
end

function url(child::ChildAssetServer, asset::AbstractAsset)
    lock(child.parent.lock) do
        is_online(asset) && return online_path(asset)
        refs, _url = refs_and_url(child.parent, asset)
        push!(refs, objectid(child))
        return _url
    end
end

function js_to_local_url(server::HTTPAssetServer, url::AbstractString)
    m = match(ASSET_URL_REGEX, url)
    if isnothing(m) || isempty(m)
        return url
    else
        key = m[1]
        refs, path = server.registered_files[string(key)]
        return path * ":" * m[2]
    end
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
        refs, filepath = rf[path]
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

setup_asset_server(server::ChildAssetServer) = nothing
setup_asset_server(server::HTTPAssetServer) = nothing
