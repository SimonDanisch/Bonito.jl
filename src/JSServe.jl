module JSServe

import Sockets
using Sockets: send

using Dates
using UUIDs
using Hyperscript
using Hyperscript: Node, children, tag
using Observables
using Markdown
using HTTP
using Deno_jll
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
using URIs

using Base: RefValue

#
function update_app! end

include("types.jl")
include("app.jl")
include("HTTPServer/HTTPServer.jl")

import .HTTPServer: browser_display, configure_server!
using .HTTPServer: Server, html, online_url, route!, get_server, file_mimetype

include("js_source.jl")
include("session.jl")

include("rendering/rendering.jl")

include("asset-serving/asset-serving.jl")
include("connection/connection.jl")
include("registry.jl")

include("serialization/serialization.jl")

include("util.jl")
include("widgets.jl")
include("display.jl")
include("offline.jl")

# Core functionality
export Page, Session, App, DOM, @js_str, ES6Module
export Slider, Button, TextField, NumberInput, Checkbox, RangeSlider, CodeEditor
export browser_display, configure_server!, Server, html, route!
export Observable, on, onany
export linkjs, evaljs, evaljs_value, onjs


end # module
