"""
We don't serve files and include anything directly as raw bytes.
Interpolating the same asset many times, will only upload the file to JS one time though.
"""
struct NoServer <: AbstractAssetServer
    registered_files::Dict{String, String}
end

NoServer() = NoServer(Dict{String, String}())

function insert_asset(server::NoServer, path::Asset)
    if haskey(server.registered_files, path)
        key = server.registered_files[path]
        return js"""
            JSServe.load_module_from_key($(key))
            """
    end
    key = unique_file_key(path)
    server.registered_files[path] = key
    return js"""
        JSServe.load_module_from_bytes($(key), $(read(path)))
        """
end

struct AssetFolder <: AbstractAssetServer
    folder::String
    registered_files::Dict{String, String}
end
