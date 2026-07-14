# Handlers

Handlers are the building blocks for serving content in Bonito. Any type that implements the `apply_handler` interface can be used with `route!` to respond to HTTP requests. This makes Bonito's routing system highly extensible - you can wrap existing handlers to add functionality like authentication, rate limiting, or logging.

## Understanding Handlers

A handler is any type that implements the `apply_handler` method:

```julia
function Bonito.HTTPServer.apply_handler(handler::YourHandlerType, context)
    request = context.request
    # ... process the request and return HTTP.Response
    return HTTP.Response(200, "Hello World")
end
```

The `context` parameter provides access to:
- `context.request` - The HTTP request object
- `context.application` - The server instance
- `context.routes` - The routes table
- `context.match` - The pattern match result (string or regex match)

Bonito's built-in `App` type is itself a handler, which is why you can use `route!(server, "/" => app)` directly.

## Creating Custom Handlers

Here's a simple example of a custom handler that logs requests:

```@example 1
using Bonito, Dates

struct LoggingHandler{T}
    handler::T
    log_file::String
end

function Bonito.HTTPServer.apply_handler(logger::LoggingHandler, context)
    request = context.request
    # Log the request
    open(logger.log_file, "a") do io
        println(io, "$(now()): $(request.method) $(request.target)")
    end
    # Delegate to wrapped handler
    return Bonito.HTTPServer.apply_handler(logger.handler, context)
end

# Usage
app = App(DOM.div("Hello World"))
logged_app = LoggingHandler(app, "requests.log")
# route!(server, "/" => logged_app)
```

This pattern of wrapping handlers is similar to middleware in other web frameworks. You can chain multiple wrappers together:

```julia
protected_logged_app = ProtectedRoute(logged_app, password_store)
```

## Built-in Handlers

Bonito provides several ready-to-use handlers:

### FolderServer

```@docs; canonical=false
FolderServer
```

### ProtectedRoute


```@docs; canonical=false
ProtectedRoute
```

## Password Storage

```@docs; canonical=false
AbstractPasswordStore
```

### SingleUser

```@docs; canonical=false
SingleUser
```

### Custom Password Stores

To implement a custom password store, subtype `AbstractPasswordStore` and implement `get_user`:

```julia
using Bonito
using Bonito: User, AbstractPasswordStore

# Example: Database-backed password store
struct DatabasePasswordStore <: AbstractPasswordStore
    db_connection::DatabaseConnection
end

function Bonito.get_user(store::DatabasePasswordStore, username::String)
    # Query database for user
    result = query(store.db_connection,
                   "SELECT * FROM users WHERE username = ?", username)

    if isempty(result)
        return nothing
    end

    # Reconstruct User from database fields
    row = result[1]
    return User(
        row.username,
        row.password_hash,  # Already hashed in database
        row.salt,
        row.iterations,
        Dict("role" => row.role)  # Optional metadata
    )
end

# The authenticate() method is automatically provided
```

**Interface Requirements:**
- Implement `get_user(store, username)` which returns a `User` or `nothing`
- The `authenticate(store, username, password)` method is automatically implemented
- Only override `authenticate()` if you need custom authentication logic

**Creating Users Manually:**

```@docs; canonical=false
User
```

## Combining Handlers

Handlers can be composed to create complex behaviors:

```julia
# Multiple layers of protection
admin_app = App(DOM.h1("Super Secret Admin"))
logged_app = LoggingHandler(admin_app, "admin.log")
protected_app = ProtectedRoute(logged_app, admin_store)

# Different protection for different routes
public_files = FolderServer("public")
protected_files = ProtectedRoute(FolderServer("private"), file_store)

server = Bonito.Server("0.0.0.0", 8080)
# Use regex route to forward all file requests to FolderServer
route!(server, r"/public/.*" => public_files)
route!(server, "/private/.*" => protected_files)
route!(server, "/admin" => protected_app)
```


## Advanced: Handler Context

The `context` object passed to handlers is a NamedTuple with the following fields:

```julia
context = (
    request = HTTP.Request,      # The HTTP request
    application = Server,         # The server instance
    routes = Routes,              # The routes table
    match = Union{String, RegexMatch}  # The pattern match result
)
```

You can access request details like:

```julia
function Bonito.HTTPServer.apply_handler(handler::MyHandler, context)
    request = context.request

    # Request method (GET, POST, etc.)
    method = request.method

    # Request path
    path = request.target

    # Headers
    user_agent = HTTP.header(request, "User-Agent", "")

    # Query parameters
    uri = URIs.URI(request.target)
    query = URIs.queryparams(uri.query)

    # Access server info
    server = context.application
    server_url = online_url(server, "/")

    # Access regex capture groups if using regex pattern
    if context.match isa RegexMatch
        captured = context.match.captures
    end

    # ...
end
```
