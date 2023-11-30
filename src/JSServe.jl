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
using ThreadPools

using Base: RefValue

# these are used in HTTPServer and need to be defined already
function update_app! end
function get_server end
function wait_for end
function wait_for_ready end

include("deno.jl")
include("types.jl")
include("HTTPServer/HTTPServer.jl")
include("app.jl")

function HTTPServer.route!(server::HTTPServer.Server, routes::Routes)
    for (key, app) in routes.routes
        HTTPServer.route!(server, key => app)
    end
end


import .HTTPServer: browser_display
using .HTTPServer: Server, html, online_url, route!, file_mimetype, delete_websocket_route!, delete_route!, use_electron_display

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
include("export.jl")
include("dashboard.jl")
include("tailwind-dashboard.jl")

include("interactive.jl")

# Core functionality
export Page, Session, App, DOM, SVG, @js_str, ES6Module, Asset, CSS
export Slider, Button, TextField, NumberInput, Checkbox, RangeSlider, CodeEditor
export browser_display, configure_server!, Server, html, route!, online_url, use_electron_display
export Observable, on, onany, bind_global
export linkjs, evaljs, evaljs_value, onjs
export NoServer, AssetFolder, HTTPAssetServer, DocumenterAssets
export NoConnection, IJuliaConnection, PlutoConnection, WebSocketConnection
export export_static, Routes, interactive_server


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
