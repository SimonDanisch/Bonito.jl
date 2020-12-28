module JSServe

import Sockets
using UUIDs, Hyperscript, JSON3, Observables
import Sockets: send, TCPServer
using Hyperscript: Node, children, tag
using HTTP, Markdown
using HTTP: Response, Request
using HTTP.Streams: Stream
using WebSockets
using WebSockets: WebSocket

using Base64
using MsgPack
using WidgetsBase
using WidgetsBase: vertical, horizontal
using SHA
using Tables
using Colors
using LinearAlgebra
using CodecZlib

include("types.jl")
include("server.jl")
include("js_source.jl")
include("session.jl")
include("observables.jl")
include("dependencies.jl")
include("http.jl")
include("util.jl")
include("widgets.jl")
include("hyperscript_integration.jl")
include("display.jl")
include("markdown_integration.jl")
include("serialization.jl")
include("offline.jl")
include("browser_display.jl")

const JSSERVE_CONFIGURATION = (
    # The URL used to which the default server listens to
    listen_url = Ref("127.0.0.1"),
    # The Port to which the default server listens to
    listen_port = Ref(9284),
    # The url Javascript uses to connect to the websocket.
    # if empty, it will use:
    # `window.location.protocol + "//" + window.location.host`
    external_url = Ref(""),
    # The url prepended to assets when served!
    # if `""`, urls are inserted into HTML in relative form!
    content_delivery_url = Ref(""),
    # Verbosity for logging!
    verbose = Ref(false)
)

"""
configure_server!(external_url="";
        listen_port=JSSERVE_CONFIGURATION.listen_port[],
        external_port=listen_port)
Configure JSServe server to be reachable from outside.
This should be used when displaying JSServe based Apps in e.g. Pluto!
`configure_server!("http://192.168.178.21")`
Will set the server to:
`external_url = "http://192.168.178.21:\$(external_port)"`
If you're using some domain, where the port doesn't need to be attached use:
`configure_server!("http://my-domain.com", external_port=nothing)`

If you set `listen_port` to something, it will also change the port the server is listening on when started!
"""
function configure_server!(external_url="";
        listen_port=JSSERVE_CONFIGURATION.listen_port[],
        external_port=listen_port)

    JSSERVE_CONFIGURATION.listen_port[] = listen_port
    if isempty(external_url)
        external_url = "http://localhost"
    end
    if external_port !== nothing
        external_url = "$(external_url):$(external_port)"
    end
    JSSERVE_CONFIGURATION.listen_url[] = "0.0.0.0"
    JSSERVE_CONFIGURATION.external_url[] = external_url
end

function has_html_display()
    for display in Base.Multimedia.displays
        # Ugh, why would textdisplay say it supports HTML??
        display isa TextDisplay && continue
        displayable(display, MIME"text/html"()) && return true
    end
    return false
end

function __init__()
    url = if haskey(ENV, "JULIA_WEBIO_BASEURL")
        ENV["JULIA_WEBIO_BASEURL"]
    else
        ""
    end
    if endswith(url, "/")
        url = url[1:end-1]
    end
    JSSERVE_CONFIGURATION.listen_url[] = get(ENV, "JSSERVE_LISTEN_URL", "127.0.0.1")
    JSSERVE_CONFIGURATION.external_url[] = url
    JSSERVE_CONFIGURATION.content_delivery_url[] = url
    JSSERVE_CONFIGURATION.listen_port[] = parse(Int, get(ENV, "WEBIO_HTTP_PORT", "8081"))

    # If there is no html inline display in the IDE that JSServe is running
    # we display things in the local browser
    if !has_html_display()
        browser_display()
    end
end

end # module
