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

function longest_common_prefix(a::AbstractString, b::AbstractString)
    len = min(length(a), length(b))
    for i in 1:len
        if a[i] != b[i]
            return a[1:(i-1)]
        end
    end
    return a[1:len]
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
        context_match = longest_common_prefix(pattern_str, relative_path)
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
