using HTTP, URIs

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

    # The full request path is in uri.path
    # We need to figure out what prefix to strip based on the route pattern
    # For regex routes like r"/public.*", we want to strip "/public" (the static prefix)
    # For string routes like "/api", we strip that exact string

    relative_path = uri.path
    context_match = context.match
    if context.match isa RegexMatch
        # For regex matches, find the common prefix between the pattern and the actual path
        # This naturally excludes regex metacharacters
        # e.g., pattern="/public/.*" and path="/public/index.html" -> common prefix="/public/"
        pattern_str = context.match.regex.pattern

        # Find the longest common prefix
        route_prefix = ""
        for i in 1:min(length(pattern_str), length(relative_path))
            if pattern_str[i] == relative_path[i]
                route_prefix *= pattern_str[i]
            else
                break
            end
        end

        context_match = route_prefix
    end

    # For string matches, strip the matched string
    if startswith(relative_path, context_match)
        relative_path = relative_path[(length(context_match) + 1):end]
    end

    # Remove leading '/' if present
    if startswith(relative_path, "/")
        relative_path = relative_path[2:end]
    end

    path = joinpath(app.folder, relative_path)
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
