module HTTPServer

using HTTP
using HTTP: Response, Request
using HTTP.Streams: Stream
import Sockets: send, TCPServer
using Sockets
using ..JSServe: App, update_app!

include("helper.jl")
include("implementation.jl")
include("browser-display.jl")
include("mimetypes.jl")

export route!, Server, html, file_mimetype

end
