using HTTP, URIs
import Base64
using MbedTLS
using Random

# PBKDF2-HMAC-SHA256 (single 32-byte block) over MbedTLS's HMAC-SHA256.
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

# Cryptographically secure random salt.
function generate_salt(length::Int=16)
    return rand(Random.RandomDevice(), UInt8, length)
end

#=============================================================================
Default Error Pages
=============================================================================#

# Default 401 Unauthorized page.
function default_auth_required_page()
    return App() do
        return DOM.div(
            DOM.h1("401: Unauthorized"),
            DOM.p("This resource requires authentication. Please provide valid credentials.")
        )
    end
end

# Default 429 Too Many Requests page.
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

# Constant-time equality: always walks the full overlap so response timing can't
# reveal how many leading bytes of a secret matched (a plain `==` short-circuits
# on the first mismatch). Branches only on the public length, never on content.
function secure_compare(a::AbstractVector{UInt8}, b::AbstractVector{UInt8})
    result = UInt8(length(a) == length(b) ? 0 : 1)
    n = min(length(a), length(b))
    @inbounds for i in 1:n
        result |= a[i] ⊻ b[i]
    end
    return result == 0
end
secure_compare(a::AbstractString, b::AbstractString) = secure_compare(codeunits(a), codeunits(b))

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
    auth_required_handler::H # both error handlers share one type param H
    rate_limited_handler::H
    # All `failed_attempts` access is concurrent (one task per request);
    # the Dict needs a lock. Also bounds growth of the per-IP buckets.
    lock::Base.ReentrantLock
    # Only honor X-Forwarded-For when explicitly told we sit behind a trusted
    # proxy — otherwise any client spoofs the header to dodge the limiter and
    # to grow the Dict without bound.
    trust_forwarded_for::Bool
    # Upper bound on tracked IPs; oldest-pruned buckets are evicted past this
    # to keep an attacker rotating XFF values from exhausting memory.
    max_tracked_ips::Int
end

# Main constructor
function ProtectedRoute(handler, password_store::AbstractPasswordStore;
                       realm::String="Protected Area",
                       max_attempts::Int=5,
                       lockout_window::Float64=60.0,
                       auth_required_handler=default_auth_required_page(),
                       rate_limited_handler=default_rate_limited_page(),
                       trust_forwarded_for::Bool=false,
                       max_tracked_ips::Int=10_000)
    ProtectedRoute(handler, password_store, realm,
                  Dict{String, Vector{Float64}}(), max_attempts, lockout_window,
                  auth_required_handler, rate_limited_handler,
                  Base.ReentrantLock(), trust_forwarded_for, max_tracked_ips)
end


# True if the request carries valid HTTP Basic credentials for the store.
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

# Identify the client for rate limiting. `X-Forwarded-For` is honored only when
# `protected.trust_forwarded_for` is set (and then takes precedence, since the
# direct peer is the proxy): the header is attacker-controlled, so without a
# trusted proxy spoofing it would let a client dodge the limit and grow
# `failed_attempts` without bound. Otherwise use the real TCP peer IP that
# `stream_handler` resolved into `context.peer_ip`. Returns "" when the client
# can't be identified, which the caller treats as "don't rate-limit" rather than
# bucketing every unidentified client together.
function get_client_ip(protected::ProtectedRoute, context)
    if protected.trust_forwarded_for
        forwarded = HTTP.header(context.request, "X-Forwarded-For", "")
        isempty(forwarded) || return strip(String(split(forwarded, ',')[1]))
    end
    return String(get(context, :peer_ip, ""))
end

# True if the client is still under its failed-attempt limit (false = blocked).
function check_rate_limit(protected::ProtectedRoute, client_ip::String)
    current_time = time()
    return lock(protected.lock) do
        # Get failed attempts for this IP
        if haskey(protected.failed_attempts, client_ip)
            attempts = protected.failed_attempts[client_ip]

            # Remove old attempts outside the lockout window
            filter!(t -> (current_time - t) < protected.lockout_window, attempts)
            # Drop the bucket entirely once it has aged out — keeps the Dict
            # from accumulating empty entries for every IP ever seen.
            if isempty(attempts)
                delete!(protected.failed_attempts, client_ip)
                return true
            end

            # Check if exceeded max attempts
            if length(attempts) >= protected.max_attempts
                @debug "Rate limit exceeded for IP" ip=client_ip attempts=length(attempts)
                return false
            end
        end
        return true
    end
end

# Record a failed authentication attempt for rate limiting.
function record_failed_attempt(protected::ProtectedRoute, client_ip::String)
    current_time = time()
    lock(protected.lock) do
        # If we are at the tracking cap and this is a new IP, evict aged-out
        # buckets first so a flood of distinct (possibly spoofed-source) IPs
        # can't grow the Dict without bound.
        if !haskey(protected.failed_attempts, client_ip) &&
           length(protected.failed_attempts) >= protected.max_tracked_ips
            prune_failed_attempts!(protected, current_time)
        end

        bucket = get!(() -> Float64[], protected.failed_attempts, client_ip)
        push!(bucket, current_time)

        # Log failed attempt for security monitoring
        @debug "Failed authentication attempt" ip=client_ip total_attempts=length(bucket)
    end
end

# Caller must hold `protected.lock`.
function prune_failed_attempts!(protected::ProtectedRoute, current_time::Float64)
    for (ip, attempts) in collect(protected.failed_attempts)
        filter!(t -> (current_time - t) < protected.lockout_window, attempts)
        isempty(attempts) && delete!(protected.failed_attempts, ip)
    end
    return
end

# Clear a client's failed attempts after a successful authentication.
function clear_failed_attempts(protected::ProtectedRoute, client_ip::String)
    lock(protected.lock) do
        if haskey(protected.failed_attempts, client_ip)
            delete!(protected.failed_attempts, client_ip)
        end
    end
end

# 401 response (rendered auth_required_handler) with a WWW-Authenticate header.
function create_auth_challenge(protected::ProtectedRoute, context)
    # Render the custom handler
    response = Bonito.HTTPServer.apply_handler(protected.auth_required_handler, context)

    # Add WWW-Authenticate header and change status to 401
    headers = copy(response.headers)
    push!(headers, "WWW-Authenticate" => "Basic realm=\"$(protected.realm)\"")

    return HTTP.Response(401, headers, response.body)
end

# 429 response (rendered rate_limited_handler) with a Retry-After header.
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
    client_ip = get_client_ip(protected, context)

    if check_auth(request, protected.password_store)
        isempty(client_ip) || clear_failed_attempts(protected, client_ip)
        return Bonito.HTTPServer.apply_handler(protected.handler, context)
    end

    # Auth failed. We can only rate-limit when we know who the client is; with no
    # identifier, bucketing every request together would let one client lock out
    # everyone, so we just re-challenge instead.
    if isempty(client_ip)
        return create_auth_challenge(protected, context)
    end
    if !check_rate_limit(protected, client_ip)
        return create_rate_limit_response(protected, context)
    end
    record_failed_attempt(protected, client_ip)
    return create_auth_challenge(protected, context)
end
