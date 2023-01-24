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

# these are used in HTTPServer and need to be defined already
function update_app! end
function get_server end

include("types.jl")
include("app.jl")
include("HTTPServer/HTTPServer.jl")

import .HTTPServer: browser_display
using .HTTPServer: Server, html, online_url, route!, file_mimetype, delete_websocket_route!, delete_route!

include("js_source.jl")
include("session.jl")

include("rendering/rendering.jl")

include("asset-serving/asset-serving.jl")
include("connection/connection.jl")
include("registry.jl")
include("server-defaults.jl")

include("serialization/serialization.jl")

include("util.jl")
include("widgets.jl")
include("display.jl")
include("offline.jl")
include("tailwind-dashboard.jl")

# Core functionality
export Page, Session, App, DOM, @js_str, ES6Module
export Slider, Button, TextField, NumberInput, Checkbox, RangeSlider, CodeEditor
export browser_display, configure_server!, Server, html, route!
export Observable, on, onany
export linkjs, evaljs, evaljs_value, onjs
export NoServer, AssetFolder, HTTPAssetServer
export NoConnection, IJuliaConnection, PlutoConnection, WebSocketConnection


function has_html_display()
    for display in Base.Multimedia.displays
        # Ugh, why would textdisplay say it supports HTML??
        display isa TextDisplay && continue
        displayable(display, MIME"text/html"()) && return true
    end
    return false
end

function __init__()
    # Use browser display if no HTML display is available
    if !has_html_display()
        browser_display()
    end
end

end # module
