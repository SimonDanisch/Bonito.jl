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
using RelocatableFolders: @path, Path, getroot

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
    listen_url = Ref("localhost"),
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
    configure_server!(;
            listen_url::String=JSSERVE_CONFIGURATION.listen_url[],
            listen_port::Integer=JSSERVE_CONFIGURATION.listen_port[],
            forwarded_port::Integer=listen_port,
            external_url=nothing,
            content_delivery_url=nothing
        )

Configures the parameters for the automatically started server.

    Parameters:

    * listen_url=JSSERVE_CONFIGURATION.listen_url[]
        The address the server listens to.
        must be 0.0.0.0, 127.0.0.1, ::, ::1, or localhost.
        If not set differently by an ENV variable, will default to 127.0.0.1

    * listen_port::Integer=JSSERVE_CONFIGURATION.listen_port[],
        The Port to which the default server listens to
        If not set differently by an ENV variable, will default to 9284

    * forwarded_port::Integer=listen_port,
        if port gets forwarded to some other port, set it here!

    * external_url=nothing
        The url from which the server is reachable.
        If served on "127.0.0.1", this will default to http://localhost:forwarded_port
        if listen_url is "0.0.0.0", this will default to http://\$(Sockets.getipaddr()):forwarded_port
        so that the server is reachable inside the local network.
        If the server should be reachable from some external dns server,
        this needs to be set here.

    * content_delivery_url=nothing
        You can server files from another server.
        Make sure any file referenced from Julia is reachable at
        content_delivery_url * "/the_file"
"""
function configure_server!(;
        listen_url=nothing,
        # The Port to which the default server listens to
        listen_port::Integer=JSSERVE_CONFIGURATION.listen_port[],
        # if port gets forwarded to some other port, set it here!
        forwarded_port::Integer=listen_port,
        # The url from which the server is reachable.
        # If served on "127.0.0.1", this will default to
        # if listen_url is "0.0.0.0", this will default to
        # Sockets.getipaddr() so that it's the ip address in the local network.
        # If the server should be reachable from some external dns server,
        # this needs to be set here
        external_url=nothing,
        # You can server files from another server.
        # Make sure any file referenced from Julia is reachable at
        # content_delivery_url * "/the_file"
        content_delivery_url=nothing
    )

    if isnothing(listen_url)
        if !isnothing(external_url)
            # if we serve to an external url, server must listen to 0.0.0.0
            listen_url = "0.0.0.0"
        else
            listen_url = JSSERVE_CONFIGURATION.listen_url[]
        end
    end

    if isnothing(external_url)
        if listen_url == "0.0.0.0"
            external_url = string(Sockets.getipaddr(), ":$forwarded_port")
        elseif listen_url in ("127.0.0.1", "localhost")
            external_url = "http://localhost:$forwarded_port"
        else
            error("Trying to listen to $(listen_url), while only \"127.0.0.1\", \"0.0.0.0\" and \"localhost\" are supported")
        end
    end
    # set the config!
    JSSERVE_CONFIGURATION.listen_url[] = listen_url
    JSSERVE_CONFIGURATION.external_url[] = external_url
    JSSERVE_CONFIGURATION.listen_port[] = listen_port
    if content_delivery_url === nothing
        JSSERVE_CONFIGURATION.content_delivery_url[] = external_url
    else
        JSSERVE_CONFIGURATION.content_delivery_url[] = content_delivery_url
    end
    return
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

    if haskey(ENV, "WEBIO_HTTP_PORT")
        JSSERVE_CONFIGURATION.listen_port[] = parse(Int, ENV["WEBIO_HTTP_PORT"])
    end

    # If there is no html inline display in the IDE that JSServe is running
    # we display things in the local browser
    if !has_html_display()
        browser_display()
    end
end

# Core functionality
export Page, Session, App, DOM, @js_str
export Slider, Button

end # module
