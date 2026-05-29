using Bonito: URI

mutable struct BrowserDisplay <: Base.Multimedia.AbstractDisplay
    server::Union{Nothing, Server}
    open_browser::Bool
    handler::Any
end

BrowserDisplay(; open_browser=true) = BrowserDisplay(nothing, open_browser, nothing)

function server(display::BrowserDisplay)
    if isnothing(display.server)
        display.server = get_server()
    end
    server = display.server
    start(server) # no-op if already running, makes sure server wasn't closed
    return server
end

function Base.close(display::BrowserDisplay)
    if !isnothing(display.server)
        close(display.server)
    end
    if !isnothing(display.handler)
        close(display.handler)
    end
    return
end



"""
    browser_display()
Forces Bonito.App to be displayed in a browser window that gets opened.
"""
function browser_display()
    displays = Base.Multimedia.displays
    if !isempty(displays) && last(displays) isa BrowserDisplay
        return
    end
    # if browserdisplay is anywhere not at the last position
    # remove it!
    filter!(x-> !(x isa BrowserDisplay), displays)
    # add it to end!
    Base.pushdisplay(BrowserDisplay())
    return
end

"""
    tryrun(cmd::Cmd)

Try to run a command. Return `true` if `cmd` runs and is successful (exits with a code of `0`).
Return `false` otherwise.
"""
function tryrun(cmd::Cmd)
    try
        return success(cmd)
    catch e
        return false
    end
end

function openurl(url::String)
    if Sys.isapple()
        tryrun(`open $url`) && return true
    elseif Sys.iswindows()
        tryrun(`powershell.exe start $url`) && return true
    elseif Sys.isunix()
        tryrun(`xdg-open $url`) && return true
        tryrun(`gnome-open $url`) && return true
    end
    tryrun(`python -mwebbrowser $(url)`) && return true
    # our last hope
    tryrun(`python3 -mwebbrowser $(url)`) && return true
    @warn("Can't find a way to open a browser, open $(url) manually!")
    return false
end

using ..Bonito: wait_for_ready, wait_for
using ..Bonito

function Base.display(display::BrowserDisplay, app::App)
    s = server(display)
    if isnothing(display.handler)
        display.handler = Bonito.DisplayHandler(s, app)
    end
    handler = display.handler
    needs_load = update_app!(handler, app)
    # Wait for app to be initialized and fully rendered
    if needs_load
        if display.open_browser
            success = openurl(online_url(handler.server, handler.route))
            if success
                handler.session.status = Bonito.DISPLAYED
                # if open_browser, we need to let the caller wait!
                wait_for(()-> isready(handler.session))
                # Showing the app only needs the session ready, not the handler
                # finished — blocking on the loading_task would hang ~timeout for
                # any loading_page app with a slow handler.
                wait_for_ready(app; wait_loading_task=false)
            end
        end
        return true
    else
        wait_for_ready(app; wait_loading_task=false)
        return false
    end
end

online_url(display::BrowserDisplay) = online_url(server(display), "/browser-display")

function has_html_display()
    for display in Base.Multimedia.displays
        # Ugh, why would textdisplay say it supports HTML??
        display isa TextDisplay && continue
        displayable(display, MIME"text/html"()) && return true
    end
    return false
end

# Electron windows are driven through whichever compatible backend the user
# has loaded — `ElectronCall` (the maintained fork) or `Electron` itself.
# No package extension is needed: Bonito never dispatches on backend types
# (`EWindow` / `ElectronDisplay` are Bonito's own structs and hold the
# backend objects as `Any`), and every backend call is a dynamic
# `current_electron().Foo(...)`. So we just look up whichever backend module
# is currently loaded. The backend stays an opt-in, hard-dependency-free
# `using` on the caller's side (ElectronCall is a test-only `[extras]` dep).
const ELECTRON_BACKENDS = ("ElectronCall", "Electron")

function current_electron()
    for name in ELECTRON_BACKENDS
        for (id, mod) in Base.loaded_modules
            id.name == name && return mod
        end
    end
    error("No Electron backend loaded — run `using ElectronCall` " *
          "(or `using Electron`) before opening Electron windows.")
end

struct EWindow
    app
    window
end

struct ElectronDisplay <: Base.Multimedia.AbstractDisplay
    window::EWindow
    browserdisplay::BrowserDisplay
end

function default_electron_args()
    if haskey(ENV, "GITHUB_ACTIONS")
        return [
            "--disable-web-security",
            "--allow-running-insecure-content",
            "--disable-features=VizDisplayCompositor",
            "--ignore-certificate-errors",
            "--ignore-ssl-errors",
            "--ignore-certificate-errors-spki-list",
            "--disable-extensions-http-throttling",
            "--log-level=3",
            "--disable-logging",
            "--silent-debugger-extension-api",
            "--enable-logging",
            "--user-data-dir=$(mktempdir())",
            "--disable-features=AccessibilityObjectModel",
            "--enable-unsafe-swiftshader",
            "--use-gl=swiftshader",
            "--disable-gpu",
        ]
    else
        return ["--user-data-dir=$(mktempdir())"]
    end
end

function default_security_config()
    EC = current_electron()
    # Bonito needs context_isolation=false because:
    # - executeJavaScript must access page-level JS objects (Bonito, WEBSOCKET, etc.)
    # - run(window, code) relies on shared context between page and Electron APIs
    return EC.SecurityConfig(
        context_isolation=false,
        sandbox=false,
        node_integration=false,
        web_security=true,
    )
end

"""
    EWindow(args...; app=nothing, options=Dict{String, Any}(), electron_args=default_electron_args())

Create an Electron window via ElectronCall. If `app` is provided, reuse that Application
instead of creating a new one (avoids multiple Electron processes).
"""
function EWindow(args...; app=nothing, options=Dict{String, Any}(), electron_args=default_electron_args())
    EC = current_electron()
    if app === nothing
        app = EC.Application(;
            additional_electron_args=electron_args,
            security=default_security_config(),
        )
    end
    if isempty(args)
        window = EC.Window(app, options)
    else
        kw = Pair{Symbol,Any}[Symbol(k) => v for (k, v) in options]
        window = EC.Window(app, args...; kw...)
    end
    return EWindow(app, window)
end

function ElectronDisplay(; app=nothing, options=Dict{String, Any}(), devtools=false, electron_args=default_electron_args())
    w = EWindow(; app=app, electron_args=electron_args, options=options)
    devtools && current_electron().toggle_devtools(w.window)
    return ElectronDisplay(w, BrowserDisplay(; open_browser=false))
end

Base.displayable(d::ElectronDisplay, ::MIME{Symbol("text/html")}) = true

function Base.display(display::ElectronDisplay, app::App)
    needs_load = Base.display(display.browserdisplay, app)
    url = online_url(display.browserdisplay)
    if needs_load
        current_electron().load(display.window.window, URI(url))
    end
    # Wait for the session to be ready, but not for the app handler to finish:
    # a loading_page app shows its spinner immediately while the handler runs
    # in the background, so blocking here would hang ~timeout (see wait_for_ready).
    wait_for_ready(app; wait_loading_task=false)
    return display
end

function use_electron_display(; app=nothing, options=Dict{String, Any}(), devtools=false, electron_args=default_electron_args())
    disp = ElectronDisplay(; app=app, devtools=devtools, options=options, electron_args=electron_args)
    filter!(Base.Multimedia.displays) do x
        # remove all other ElectronDisplays
        if x isa ElectronDisplay
            close(x)
            return false
        else
            return true
        end
    end
    Base.Multimedia.pushdisplay(disp)
    return disp
end

function Base.run(win::EWindow, args...)
    run(win.window, args...)
end

function Base.close(win::EWindow; close_app::Bool=false)
    if win.window.exists
        close(win.window)
    end
    if close_app && win.app.exists
        close(win.app)
    end
    return
end

function Base.close(display::ElectronDisplay)
    # Close the Bonito handler/session first so connections are properly shut down,
    # then close the Electron window. Don't close the server - it's shared (GLOBAL_SERVER)
    # and may be reused by subsequent displays.
    bd = display.browserdisplay
    if !isnothing(bd.handler)
        close(bd.handler)
        bd.handler = nothing
    end
    close(display.window)
    return nothing
end
