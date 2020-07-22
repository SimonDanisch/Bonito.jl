module JSServe

import Sockets
using UUIDs, Hyperscript, Hyperscript, JSON3, Observables
import Sockets: send, TCPServer
using Hyperscript: Node, children, tag
using HTTP, Markdown
using HTTP: Response, Request
using HTTP.Streams: Stream
using WebSockets
using Base64
using MsgPack
using WidgetsBase
using WidgetsBase: vertical, horizontal
using SHA
using Tables
using AbstractTrees
using Colors
using LinearAlgebra

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
include("figma.jl")
include("offline.jl")

const JSSERVE_CONFIGURATION = (
    # The URL used to which the default server listens to
    listen_url = Ref("0.0.0.0"),
    # The Port to which the default server listens to
    listen_port = Ref(8081),
    # The url Javascript uses to connect to the websocket.
    # if empty, it will use:
    # `window.location.protocol + "//" + window.location.host`
    websocket_proxy = Ref(""),
    # The url prepended to assets when served!
    # if `""`, urls are inserted into HTML in relative form!
    content_delivery_url = Ref(""),
    # Verbosity for logging!
    verbose = Ref(false)
)

function __init__()
    url = if haskey(ENV, "JULIA_WEBIO_BASEURL")
        ENV["JULIA_WEBIO_BASEURL"]
    else
        ""
    end
    if endswith(url, "/")
        url = url[1:end-1]
    end
    JSSERVE_CONFIGURATION.websocket_proxy[] = url
    JSSERVE_CONFIGURATION.content_delivery_url[] = url
    JSSERVE_CONFIGURATION.listen_port[] = parse(Int, get(ENV, "WEBIO_HTTP_PORT", "8081"))

    atexit() do
        # remove session folder, in which we store data dependencies temporary
        # TODO remove whenever a session is closed to not accumulate waste until julia
        # gets closed
        rm(dependency_path("session_temp_data"), recursive=true, force=true)
    end
    # start_gc_task()
end


end # module
