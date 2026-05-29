module HTTPServer

using HTTP
using HTTP: Response, Request
# HTTP.jl 2.0 dropped the `HTTP.Streams` submodule; `Stream` now lives at the
# top level of HTTP.
using HTTP: Stream
import Sockets: send, TCPServer
using Sockets
using ..Bonito: App, update_app!, get_server

include("helper.jl")
include("implementation.jl")
include("browser-display.jl")
include("mimetypes.jl")

export route!, has_route, get_route, Server, html, file_mimetype

end
