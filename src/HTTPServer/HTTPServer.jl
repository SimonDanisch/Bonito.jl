module HTTPServer

using HTTP
using HTTP: Response, Request
using HTTP.Streams: Stream
import Sockets: send, TCPServer
using Sockets

include("helper.jl")
include("implementation.jl")
include("browser-display.jl")

end
