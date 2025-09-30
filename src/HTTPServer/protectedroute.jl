using HTTP, URIs
import Base64
using MbedTLS
using Random

"""
    pbkdf2_simple(password::String, salt::Vector{UInt8}; iterations::Int=10_000) -> Vector{UInt8}

Simple PBKDF2-HMAC-SHA256 implementation using MbedTLS.

# Arguments
- `password::String`: The password to hash
- `salt::Vector{UInt8}`: Random salt (should be at least 16 bytes)
- `iterations::Int`: Number of iterations (default: 10,000)

# Returns
- `Vector{UInt8}`: Derived key (32 bytes)

This uses MbedTLS's HMAC-SHA256.
"""
function pbkdf2_simple(password::String, salt::Vector{UInt8}; iterations::Int=10_000)
    password_bytes = Vector{UInt8}(codeunits(password))

    # PBKDF2 with single block (32 bytes output from SHA256)
    # Block number as big-endian UInt32: 0x00000001
    block_num = reinterpret(UInt8, [hton(UInt32(1))])

    # U1 = HMAC(password, salt || block_num)
    u = MbedTLS.digest(MbedTLS.MD_SHA256, vcat(salt, block_num), password_bytes)
    result = copy(u)

    # U2...Uc = HMAC(password, U_{c-1})
    # XOR each iteration with the result
    for _ in 2:iterations
        u = MbedTLS.digest(MbedTLS.MD_SHA256, u, password_bytes)
        result .⊻= u  # XOR accumulation
    end

    return result
end

"""
    generate_salt(length::Int=16) -> Vector{UInt8}

Generate a cryptographically secure random salt.
"""
function generate_salt(length::Int=16)
    return rand(Random.RandomDevice(), UInt8, length)
end

#=============================================================================
Default Error Pages
=============================================================================#

"""
    default_auth_required_page() -> App

Default 401 Unauthorized page.
"""
function default_auth_required_page()
    return App() do
        return DOM.div(
            DOM.h1("401: Unauthorized"),
            DOM.p("This resource requires authentication. Please provide valid credentials.")
        )
    end
end

"""
    default_rate_limited_page() -> App

Default 429 Too Many Requests page.
"""
function default_rate_limited_page()
    return App() do
        return DOM.div(
            DOM.h1("429: Too Many Requests"),
            DOM.p("Too many failed authentication attempts. Please try again later.")
        )
    end
end

#=============================================================================
User and Password Store Abstractions
=============================================================================#

"""
    User

Represents a user with authentication credentials.

# Fields
- `username::String`: The username
- `password_hash::Vector{UInt8}`: PBKDF2 derived key
- `salt::Vector{UInt8}`: Random salt for password hashing
- `iterations::Int`: PBKDF2 iteration count
- `metadata::Dict{String, Any}`: Optional user metadata (roles, permissions, etc.)
"""
struct User
    username::String
    password_hash::Vector{UInt8}
    salt::Vector{UInt8}
    iterations::Int
    metadata::Dict{String, Any}
end

"""
    User(username::String, password::String; iterations::Int=10_000, metadata::Dict{String, Any}=Dict{String, Any}())

Create a new user with automatic password hashing using PBKDF2.
"""
function User(
    username::AbstractString,
    password::AbstractString;
              iterations::Int=10_000,
              metadata::Dict{String, Any}=Dict{String, Any}())
    salt = generate_salt(16)
    password_hash = pbkdf2_simple(password, salt; iterations=iterations)
    return User(username, password_hash, salt, iterations, metadata)
end

# Constant-time comparison to prevent timing attacks
# TODO, actually implement this?
# TODO, how important is this for now?
secure_compare(a, b) = a == b

"""
    authenticate(user::User, password::String) -> Bool

Authenticate a user with the provided password.
"""
function authenticate(user::User, password::AbstractString)
    provided_hash = pbkdf2_simple(String(password), user.salt; iterations=user.iterations)
    return secure_compare(provided_hash, user.password_hash)
end

"""
    AbstractPasswordStore

Abstract interface for password storage and authentication.

# Required Methods
- `get_user(store, username::String)::Union{User, Nothing}`: Retrieve user by username

# Provided Methods
- `authenticate(store, username::String, password::String)::Bool`: Verify credentials (implemented via get_user)

# Implementation Guide
Subtypes only need to implement `get_user()`. The `authenticate()` method will automatically:
1. Call `get_user()` to retrieve the user
2. Verify the password using the User's authenticate method
3. Return true if credentials match, false otherwise

For custom authentication logic (e.g., LDAP), you can override `authenticate()`.
"""
abstract type AbstractPasswordStore end

"""
    get_user(store::AbstractPasswordStore, username::String) -> Union{User, Nothing}

Retrieve a user by username from the password store.
Must be implemented by all AbstractPasswordStore subtypes.
"""
function get_user(store::AbstractPasswordStore, username::AbstractString)
    error("get_user not implemented for $(typeof(store))")
end

"""
    authenticate(store::AbstractPasswordStore, username::String, password::String) -> Bool

Authenticate user credentials against the password store.
Default implementation retrieves the user via get_user() and verifies the password.
Override this method only if you need custom authentication logic.
"""
function authenticate(
    store::AbstractPasswordStore,
    username::AbstractString,
    password::AbstractString,
)
    user = get_user(store, username)
    if isnothing(user)
        return false
    end
    return authenticate(user, password)
end

"""
    SingleUser <: AbstractPasswordStore

Simple password store for single-user authentication.

# Fields
- `user::User`: The single user
"""
struct SingleUser <: AbstractPasswordStore
    user::User
end

"""
    SingleUser(username::String, password::String; iterations::Int=10_000)

Create a single-user password store with automatic password hashing.

# Example
```julia
store = SingleUser("admin", "secret123")
authenticated = authenticate(store, "admin", "secret123")  # true
```
"""
function SingleUser(
    username::AbstractString, password::AbstractString; iterations::Int=10_000
)
    user = User(username, password; iterations=iterations)
    return SingleUser(user)
end

# Implement required interface: only get_user() is needed
function get_user(store::SingleUser, username::AbstractString)
    if secure_compare(username, store.user.username)
        return store.user
    end
    return nothing
end

# authenticate() is automatically provided by AbstractPasswordStore

"""
    ProtectedRoute{T, PS <: AbstractPasswordStore}

A wrapper that adds HTTP Basic Authentication to any type that implements `apply_handler`.
Can wrap Bonito.App, FolderServer, or any other handler type.

# Security Notes
- **REQUIRES HTTPS**: HTTP Basic Auth sends credentials with every request.
  Without HTTPS, credentials are transmitted in plaintext (Base64 is NOT encryption).
- **Experimental**: This is a simple implementation for basic use cases with no security guarantees.
- **Rate Limiting**: Built-in protection against brute force attacks (max 5 attempts per IP per minute).
- **PBKDF2 Password Hashing**: Uses PBKDF2-HMAC-SHA256 with 10,000 iterations and random salt.
- **Extensible**: Use custom AbstractPasswordStore implementations for multi-user or database-backed auth.

# Fields
- `handler::T`: The wrapped handler (e.g., Bonito.App, FolderServer, etc.)
- `password_store::PS`: Password store implementing AbstractPasswordStore interface
- `realm::String`: Authentication realm name (default: "Protected Area")
- `failed_attempts::Dict{String, Vector{Float64}}`: IP -> timestamps of failed attempts
- `max_attempts::Int`: Maximum failed attempts allowed (default: 5)
- `lockout_window::Float64`: Time window in seconds for rate limiting (default: 60.0)
- `auth_required_handler`: Handler for 401 responses (default: built-in HTML page)
- `rate_limited_handler`: Handler for 429 responses (default: built-in HTML page)

# Example
```julia
# Create app
app = App() do
    return DOM.h1("Hello World")
end

# Create password store
store = SingleUser("admin", "secret123")

# Create protected route
protected_app = ProtectedRoute(app, store)

# With custom error pages
auth_page = App() do
    return DOM.div(
        DOM.h1("Authentication Required"),
        DOM.p("Please log in to access this resource")
    )
end

rate_limit_page = App() do
    return DOM.div(
        DOM.h1("Too Many Attempts"),
        DOM.p("Please wait before trying again")
    )
end

protected_app = ProtectedRoute(app, store;
                               auth_required_handler=auth_page,
                               rate_limited_handler=rate_limit_page)

# Add to server (MUST use HTTPS in production!)
server = Bonito.Server("0.0.0.0", 8443)  # Use SSL/TLS
route!(server, "/" => protected_app)
```
"""
struct ProtectedRoute{T, PS <: AbstractPasswordStore, H}
    handler::T
    password_store::PS
    realm::String
    failed_attempts::Dict{String, Vector{Float64}}
    max_attempts::Int
    lockout_window::Float64
    auth_required_handler::H # For simplicity and performance, use same type her
    rate_limited_handler::H
end

# Main constructor
function ProtectedRoute(handler, password_store::AbstractPasswordStore;
                       realm::String="Protected Area",
                       max_attempts::Int=5,
                       lockout_window::Float64=60.0,
                       auth_required_handler=default_auth_required_page(),
                       rate_limited_handler=default_rate_limited_page())
    ProtectedRoute(handler, password_store, realm,
                  Dict{String, Vector{Float64}}(), max_attempts, lockout_window,
                  auth_required_handler, rate_limited_handler)
end


"""
    check_auth(request::HTTP.Request, password_store::AbstractPasswordStore) -> Bool

Check if the HTTP request contains valid Basic Authentication credentials.
Uses the password store's authenticate method.
"""
function check_auth(request::HTTP.Request, password_store::AbstractPasswordStore)
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
            # Delegate to password store for authentication
            return authenticate(password_store, provided_username, provided_password)
        end
    catch e
        # Base64 decode failed or other error - log for security monitoring
        @warn "Authentication decode error" exception=e
        return false
    end

    return false
end

"""
    get_client_ip(request::HTTP.Request) -> String

Extract client IP address from request, checking X-Forwarded-For header first.
"""
function get_client_ip(request::HTTP.Request)
    # Check X-Forwarded-For header (for proxies/load balancers)
    forwarded = HTTP.header(request, "X-Forwarded-For", "")
    if !isempty(forwarded)
        # Take first IP in comma-separated list
        return String(split(forwarded, ',')[1])
    end
    # Fallback to direct connection (if available in context)
    return "unknown"
end

"""
    check_rate_limit(protected::ProtectedRoute, client_ip::String) -> Bool

Check if client has exceeded rate limit for failed authentication attempts.
Returns true if request should be allowed, false if rate limited.
"""
function check_rate_limit(protected::ProtectedRoute, client_ip::String)
    current_time = time()
    # Get failed attempts for this IP
    if haskey(protected.failed_attempts, client_ip)
        attempts = protected.failed_attempts[client_ip]

        # Remove old attempts outside the lockout window
        filter!(t -> (current_time - t) < protected.lockout_window, attempts)

        # Check if exceeded max attempts
        if length(attempts) >= protected.max_attempts
            @warn "Rate limit exceeded for IP" ip=client_ip attempts=length(attempts)
            return false
        end
    end

    return true
end

"""
    record_failed_attempt(protected::ProtectedRoute, client_ip::String)

Record a failed authentication attempt for rate limiting.
"""
function record_failed_attempt(protected::ProtectedRoute, client_ip::String)
    current_time = time()

    if !haskey(protected.failed_attempts, client_ip)
        protected.failed_attempts[client_ip] = Float64[]
    end

    push!(protected.failed_attempts[client_ip], current_time)

    # Log failed attempt for security monitoring
    @warn "Failed authentication attempt" ip=client_ip total_attempts=length(protected.failed_attempts[client_ip])
end

"""
    clear_failed_attempts(protected::ProtectedRoute, client_ip::String)

Clear failed attempts for a client after successful authentication.
"""
function clear_failed_attempts(protected::ProtectedRoute, client_ip::String)
    if haskey(protected.failed_attempts, client_ip)
        delete!(protected.failed_attempts, client_ip)
    end
end

"""
    create_auth_challenge(protected::ProtectedRoute, context) -> HTTP.Response

Create an HTTP 401 Unauthorized response with WWW-Authenticate header.
Renders the auth_required_handler App.
"""
function create_auth_challenge(protected::ProtectedRoute, context)
    # Render the custom handler
    response = Bonito.HTTPServer.apply_handler(protected.auth_required_handler, context)

    # Add WWW-Authenticate header and change status to 401
    headers = copy(response.headers)
    push!(headers, "WWW-Authenticate" => "Basic realm=\"$(protected.realm)\"")

    return HTTP.Response(401, headers, response.body)
end

"""
    create_rate_limit_response(protected::ProtectedRoute, context) -> HTTP.Response

Create an HTTP 429 Too Many Requests response.
Renders the rate_limited_handler App.
"""
function create_rate_limit_response(protected::ProtectedRoute, context)
    # Render the custom handler
    response = Bonito.HTTPServer.apply_handler(protected.rate_limited_handler, context)

    # Add Retry-After header and change status to 429
    headers = copy(response.headers)
    push!(headers, "Retry-After" => "60")

    return HTTP.Response(429, headers, response.body)
end

# Enable route!(server, "/" => protected_route)
function Bonito.HTTPServer.apply_handler(protected::ProtectedRoute, context)
    request = context.request
    client_ip = get_client_ip(request)

    # Check authentication first
    auth_valid = check_auth(request, protected.password_store)

    if auth_valid
        # Authentication successful - clear any failed attempts and allow through
        clear_failed_attempts(protected, client_ip)
        # Delegate to wrapped handler
        return Bonito.HTTPServer.apply_handler(protected.handler, context)
    end

    # Authentication failed - check if rate limited
    if !check_rate_limit(protected, client_ip)
        return create_rate_limit_response(protected, context)
    end

    # Record failed attempt and return auth challenge
    record_failed_attempt(protected, client_ip)
    return create_auth_challenge(protected, context)
end
