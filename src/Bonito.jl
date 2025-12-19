module Bonito

import Sockets
using Sockets: send

using OrderedCollections
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

using Base: RefValue

# these are used in HTTPServer and need to be defined already
function update_app! end
function get_server end
function wait_for end
function wait_for_ready end

include("deno.jl")
include("types.jl")
include("HTTPServer/HTTPServer.jl")
include("HTTPServer/folderserver.jl")
include("HTTPServer/protectedroute.jl")
include("app.jl")

function HTTPServer.route!(server::HTTPServer.Server, routes::Routes)
    for (key, app) in routes.routes
        HTTPServer.route!(server, key => app)
    end
end


import .HTTPServer: browser_display, EWindow
using .HTTPServer: Server, html, online_url, route!, file_mimetype, delete_websocket_route!, delete_route!, use_electron_display

include("js_source.jl")
include("session.jl")

include("rendering/rendering.jl")

include("asset-serving/asset-serving.jl")
include("connection/connection.jl")
include("registry.jl")

using JSON
include("server-defaults.jl")

include("serialization/serialization.jl")

include("util.jl")
include("widgets.jl")
include("display.jl")
include("export.jl")
include("components.jl")
include("connection_indicator.jl")
include("tailwind-dashboard.jl")

include("interactive.jl")

# Core functionality
export Page, Session, App, DOM, SVG, @js_str, ES6Module, Asset, CSS
export Slider, Button, TextField, NumberInput, Checkbox, RangeSlider, CodeEditor, HierarchicalMenu, HierarchicalMenuItem, HierarchicalSubMenu
export browser_display, configure_server!, Server, show_html, html, route!, online_url, use_electron_display
export Observable, on, onany, bind_global
export linkjs, evaljs, evaljs_value, onjs
export NoServer, AssetFolder, HTTPAssetServer, DocumenterAssets
export NoConnection, IJuliaConnection, PlutoConnection, WebSocketConnection
export export_static, Routes, interactive_server
export Card, Grid, FileInput, Dropdown, Styles, Col, Row
export Labeled, StylableSlider, Centered
export interactive_server
export ChoicesBox, ChoicesJSParams
export ProtectedRoute, User, SingleUser, AbstractPasswordStore, FolderServer
export ConnectionIndicator, AbstractConnectionIndicator
export get_metadata, set_metadata!
export cleanup_globals

function has_html_display()
    for display in Base.Multimedia.displays
        # Ugh, why would textdisplay say it supports HTML??
        display isa TextDisplay && continue
        displayable(display, MIME"text/html"()) && return true
    end
    return false
end

"""
    cleanup_globals()

Cleans up global state (servers, sessions, tasks) for precompilation compatibility.
On Julia 1.11+, this is called automatically via atexit (which runs before serialization).
On Julia 1.10, this must be called manually after precompilation workloads.
"""
function cleanup_globals()
    for (_, (_, close_ref)) in SERVER_CLEANUP_TASKS
        close_ref[] = false
    end
    empty!(SERVER_CLEANUP_TASKS)
    CURRENT_SESSION[] = nothing
    if !isnothing(GLOBAL_SERVER[])
        close(GLOBAL_SERVER[])
    end
    GLOBAL_SERVER[] = nothing
    return
end

function __init__()
    # Use browser display if no HTML display is available
    if !has_html_display()
        browser_display()
    end
    # Register atexit for runtime cleanup (when Julia exits normally)
    # Note: This doesn't affect precompilation since __init__ doesn't run during precompile
    atexit(cleanup_globals)
end

end # module
