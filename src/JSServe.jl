module JSServe

import AssetRegistry, Sockets
using UUIDs, Hyperscript, Hyperscript, JSON3, Observables
import Sockets: send, TCPServer
using Hyperscript: Node, children, tag
using HTTP, Markdown
using HTTP: Response, Request
using HTTP.Streams: Stream
using WebSockets
using Base64
using MsgPack

include("compat.jl")
include("types.jl")
include("js_source.jl")
include("session.jl")
include("observables.jl")
include("dependencies.jl")
include("http.jl")
include("util.jl")
include("widgets.jl")
include("hyperscript_integration.jl")
include("display.jl")
include("jscall.jl")
include("markdown_integration.jl")
include("serialization.jl")
include("diffing.jl")


function __init__()
    url = get(ENV, "JULIA_WEBIO_BASEURL") do
        base = get(ENV, "WEBIO_SERVER_HOST_URL", "127.0.0.1")
        port = get(ENV, "WEBIO_HTTP_PORT", "8081")
        return "http://" * base * ":" * port
    end
    if endswith(url, "/")
        url = url[1:end-1]
    end
    server_proxy_url[] = url
    atexit() do
        # remove session folder, in which we store data dependencies temporary
        # TODO remove whenever a session is closed to not accumulate waste until julia
        # gets closed
        rm(dependency_path("session_temp_data"), recursive=true, force=true)
    end
end


end # module
