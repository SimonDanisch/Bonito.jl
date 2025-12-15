"""
# Inteface for FrontendConnection

```julia
struct MyConnection <: FrontendConnection
end
```

Needs to have a constructor with 0 arguments:
```julia
MyConnection()
```

Needs to overload `Base.write` for sending binary data
```julia
Base.write(connection::MyConnection, bytes::AbstractVector{UInt8})
```

Needs to implement isopen to indicate status of connection
```julia
Base.isopen(c::MyConnection)
```

Setup connection will be called before rendering any dom with `session`.
The return value will be inserted into the DOM of the rendered App and can be used to
do the JS part of opening the connection.
```julia
Bonito.setup_connection(session::Session{IJuliaConnection})::Union{JSCode, Nothing}
```

One can overload `use_parent_session`, to turn on rendering dom objects inside sub-sessions while keeping one parent session
managing the connection alive.
This is handy for IJulia/Pluto, since the parent session just needs to be initialized one time and can stay active and globally store objects used multiple times across doms.
```Julia
Bonito.use_parent_session(::Session{MyConnection}) = false/false
```
"""
FrontendConnection

"""
Websocket based connection type
"""
abstract type AbstractWebsocketConnection <: FrontendConnection end

open!(connection) = nothing

# fallback for connections not supporting
# a slow / fast connection
function write_large(ws, binary)
    write(ws, binary)
end

include("sub-connection.jl")
include("websocket-handler.jl")
include("websocket.jl")
include("dual-websocket.jl")
include("ijulia.jl")
include("pluto.jl")
include("no-connection.jl")
