######
######
#### Register default asset servers and connections
####


function register_type!(condition::Function, ::Type{T}, available_types::Vector{Pair{DataType, Function}}) where T
    index = findfirst(((type, c),)-> type == T, available_types)
    # constructing Pair like this prevents it from getting converted to the abstract Pair{DataType, Function} type
    pair = Pair{DataType, Function}(T, condition)
    if isnothing(index)
        push!(available_types, pair)
    else
        # connections shouldn't be overwritten, but this is handy for development!
        @warn("replacing existing type for $(T)")
        available_types[index] = pair
    end
    return
end

function force_type!(conn, forced_types::Base.RefValue)
    forced_types[] = conn
end

function force_type(f, conn, forced_types::Base.RefValue)
    try
        force_connection!(conn, forced_types)
        f()
    finally
        force_connection!(nothing, forced_types)
    end
end

function default_type(forced::Base.RefValue, available::Vector{Pair{DataType, Function}})
    if !isnothing(forced[])
        return forced[]
    else
        for i in length(available):-1:1 # start from last inserted
            type_or_nothing = available[i][2]()# ::Union{FrontendConnection, AbstractAssetServer, Nothing}
            isnothing(type_or_nothing) || return type_or_nothing
        end
        error("No type found. This can only happen if someone messed with `$(available)`")
    end
end

const AVAILABLE_ASSET_SERVERS = Pair{DataType, Function}[]

"""
    register_asset_server!(condition::Function, ::Type{<: AbstractAssetServer})

Registers a new asset server type.
`condition` is a function that should return `nothing`, if the asset server type shouldn't be used, and an initialized asset server object, if the conditions are right.
E.g. The `JSServe.NoServer` be used inside an IJulia notebook so it's registered like this:
```julia
register_asset_server!(NoServer) do
    if isdefined(Main, :IJulia)
        return NoServer()
    end
    return nothing
end
```
The last asset server registered takes priority, so if you register a new connection last in your Package, and always return it,
You will overwrite the connection type for any other package.
If you want to force usage temporary, try:
```julia
force_asset_server(YourAssetServer()) do
    ...
end
# which is the same as:
force_asset_server!(YourAssetServer())
...
force_asset_server!()
```
"""
function register_asset_server!(condition::Function, ::Type{C}) where C <: AbstractAssetServer
    register_type!(condition, C, AVAILABLE_ASSET_SERVERS)
    return
end

const FORCED_ASSET_SERVER = Base.RefValue{Union{Nothing, AbstractAssetServer}}(nothing)

function force_asset_server!(conn::Union{Nothing, AbstractAssetServer}=nothing)
    force_type!(conn, FORCED_ASSET_SERVER)
end

function force_asset_server(f, conn::Union{Nothing, AbstractAssetServer})
    force_type(f, conn, FORCED_ASSET_SERVER)
end

function default_asset_server()
    return default_type(FORCED_ASSET_SERVER, AVAILABLE_ASSET_SERVERS)
end


const AVAILABLE_CONNECTIONS = Pair{DataType, Function}[]

"""
    register_connection!(condition::Function, ::Type{<: FrontendConnection})

Registers a new Connection type.

condition is a function that should return `nothing`, if the connection type shouldn't be used, and an initialized Connection, if the conditions are right.
E.g. The IJulia connection should only be used inside an IJulia notebook so it's registered like this:
```julia
register_connection!(IJuliaConnection) do
    if isdefined(Main, :IJulia)
        return IJuliaConnection()
    end
    return nothing
end
```
The last connection registered take priority, so if you register a new connection last in your Package, and always return it,
You will overwrite the connection type for any other package.
If you want to force usage temporary, try:
```julia
force_connection(YourConnectionType()) do
    ...
end
# which is the same as:
force_connection!(YourConnectionType())
...
force_connection!()
```
"""
function register_connection!(condition::Function, ::Type{C}) where C <: FrontendConnection
    register_type!(condition, C, AVAILABLE_CONNECTIONS)
    return
end

const FORCED_CONNECTION = Base.RefValue{Union{Nothing, FrontendConnection}}(nothing)

function force_connection!(conn::Union{Nothing, FrontendConnection}=nothing)
    force_type!(conn, FORCED_CONNECTION)
end

function force_connection(f, conn::Union{Nothing, FrontendConnection})
    force_type(f, conn, FORCED_CONNECTION)
end

const FORCE_SUBSESSION_RENDERING = Base.RefValue(false)

function force_subsession!(use_subsession::Bool=false)
    FORCE_SUBSESSION_RENDERING[] = use_subsession
end

function _use_parent_session(session::Session)
    if FORCE_SUBSESSION_RENDERING[]
        return true
    else
        return use_parent_session(session)
    end
end

function default_connection()
    return default_type(FORCED_CONNECTION, AVAILABLE_CONNECTIONS)
end

use_parent_session(::Session) = false
use_parent_session(::Session{IJuliaConnection}) = true
use_parent_session(::Session{PlutoConnection}) = true
use_parent_session(::Session{WebSocketConnection}) = false

# HTTPAssetServer is the fallback, so it's registered first (lower priority),
# and never returns nothing
register_asset_server!(HTTPAssetServer) do
    return HTTPAssetServer()
end

register_asset_server!(NoServer) do
    if isdefined(Main, :IJulia) || isdefined(Main, :PlutoRunner) | isdefined(Main, :Documenter)
        return NoServer()
    else
        return  nothing
    end
end

# Needs to be globally shared while building the docs
# TODO, reuse the same AssetFolder instance more cleanly
const DOCUMENTER_ASSETS = AssetFolder()
register_asset_server!(AssetFolder) do
    if isdefined(Main, :Documenter)
        return DOCUMENTER_ASSETS
    else
        return nothing
    end
end

# Websocket is the fallback, so it's registered first (lower priority),
# and never returns nothing
register_connection!(WebSocketConnection) do
    return WebSocketConnection()
end

register_connection!(NoConnection) do
    if isdefined(Main, :Documenter)
        force_subsession!(true)
        return NoConnection()
    end
    return nothing
end

register_connection!(IJuliaConnection) do
    isdefined(Main, :IJulia) && return IJuliaConnection()
    return nothing
end

register_connection!(PlutoConnection) do
    isdefined(Main, :PlutoRunner) && return PlutoConnection()
    return nothing
end


const COMPRESSION_ENABLED = RefValue{Bool}(false)

default_compression() = COMPRESSION_ENABLED[]
default_compression!(enable) = (COMPRESSION_ENABLED[] = enable)
