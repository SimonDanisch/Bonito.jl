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
    registered_files::Dict{String, String}
end
