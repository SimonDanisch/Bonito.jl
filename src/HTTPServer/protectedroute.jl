using HTTP, URIs
import Base64

"""
    ProtectedRoute{T}

A wrapper that adds HTTP Basic Authentication to any type that implements `apply_handler`.
Can wrap Bonito.App, FolderServer, or any other handler type.

# Fields
- `handler::T`: The wrapped handler (e.g., Bonito.App, FolderServer, etc.)
- `username::String`: Required username for authentication
- `password::String`: Required password for authentication
- `realm::String`: Authentication realm name (default: "Protected Area")

# Example
```julia
# Protect a Bonito App
app = App(() -> dom"h1"("Hello World"))
protected_app = ProtectedRoute(app, "admin", "secret123")

# Protect a FolderServer
folder_server = FolderServer("public")
protected_folder = ProtectedRoute(folder_server, "user", "pass456")

# Add to server
server = Bonito.Server("0.0.0.0", 8080)
route!(server, "/" => protected_app)
route!(server, r".*" => protected_folder)
```
"""
struct ProtectedRoute{T}
    handler::T
    username::String
    password::String
    realm::String
end

# Constructor with default realm
ProtectedRoute(handler, username::String, password::String) =
    ProtectedRoute(handler, username, password, "Protected Area")

"""
    check_auth(request::HTTP.Request, username::String, password::String) -> Bool

Check if the HTTP request contains valid Basic Authentication credentials.
"""
function check_auth(request::HTTP.Request, username::String, password::String)
    auth_header = HTTP.header(request, "Authorization", "")

    # Check if Authorization header exists and starts with "Basic "
    if !startswith(auth_header, "Basic ")
        return false
    end

    try
        # Extract and decode the Base64 credentials
        encoded_credentials = auth_header[7:end]  # Remove "Basic " prefix
        decoded_credentials = String(Base64.base64decode(encoded_credentials))

        # Split username:password
        if ':' in decoded_credentials
            provided_username, provided_password = split(decoded_credentials, ':', limit=2)
            return provided_username == username && provided_password == password
        end
    catch
        # Base64 decode failed or other error
        return false
    end

    return false
end

"""
    create_auth_challenge(realm::String) -> HTTP.Response

Create an HTTP 401 Unauthorized response with WWW-Authenticate header.
"""
function create_auth_challenge(realm::String)
    headers = [
        "WWW-Authenticate" => "Basic realm=\"$realm\"",
        "Content-Type" => "text/html; charset=utf-8"
    ]

    body = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>401 Unauthorized</title>
    </head>
    <body>
        <h1>401 Unauthorized</h1>
        <p>This resource requires authentication. Please provide valid credentials.</p>
    </body>
    </html>
    """
    return HTTP.Response(401, headers, body)
end

# Enable route!(server, "/" => protected_route)
function Bonito.HTTPServer.apply_handler(protected::ProtectedRoute, context)
    request = context.request
    # Check authentication
    if !check_auth(request, protected.username, protected.password)
        return create_auth_challenge(protected.realm)
    end
    # Authentication successful, delegate to wrapped handler
    return Bonito.HTTPServer.apply_handler(protected.handler, context)
end
