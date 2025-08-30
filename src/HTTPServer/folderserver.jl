using Bonito, HTTP, URIs

"""
    FolderServer(folder::String)
A simple file server that serves files from the specified folder.
Example with a static site generated with Bonito:
```julia
# Build a static site
app = App(()-> DOM.div("Hello World"));
routes = Routes(
    "/" => app
    # Add more routes as needed
)
export_static("build", routes)
# Serve the static site from the build folder
server = Bonito.Server("0.0.0.0", 8982)
route!(server, r".*" => FolderServer("build"))
```
"""
struct FolderServer
    folder::String
end

# Enable route!(server, "/" => app)
function Bonito.HTTPServer.apply_handler(app::FolderServer, context)
    request = context.request
    uri = URI(request.target)
    path = joinpath(app.folder, uri.path[2:end])  # Remove leading '/'
    if !isfile(path)
        path = joinpath(path, "index.html")
    end
    if isfile(path)
        header = [
            "Access-Control-Allow-Origin" => "*",
            "Content-Type" => Bonito.file_mimetype(path),
        ]
        return HTTP.Response(200, header, body = read(path))
    else
        return HTTP.Response(404, "File not found")
    end
end
