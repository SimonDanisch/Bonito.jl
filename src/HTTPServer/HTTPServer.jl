module HTTPServer

using HTTP
using HTTP: Response, Request
using HTTP.Streams: Stream
import Sockets: send, TCPServer
using Sockets
using ..Bonito: App, update_app!, get_server
import ..Bonito  # for runtime-qualified access (e.g. Bonito.stop_cleanup_task!, defined after this submodule loads)

include("helper.jl")
include("implementation.jl")
include("browser-display.jl")
include("mimetypes.jl")

export route!, has_route, get_route, Server, html, file_mimetype

end
