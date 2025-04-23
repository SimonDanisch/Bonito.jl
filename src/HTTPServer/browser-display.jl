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
                wait_for_ready(app)
            end
        end
        return true
    else
        wait_for_ready(app)
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

# Poor mans Require.jl for Electron
const ELECTRON_PKG_ID = Base.PkgId(Base.UUID("a1bb12fb-d4d1-54b4-b10a-ee7951ef7ad3"), "Electron")
function Electron()
    if haskey(Base.loaded_modules, ELECTRON_PKG_ID)
        return Base.loaded_modules[ELECTRON_PKG_ID]
    else
        error("Please Load Electron, if you want to use it!")
    end
end

struct ElectronDisplay{EWindow} <: Base.Multimedia.AbstractDisplay
    window::EWindow # a type parameter here so, that we dont need to depend on Electron Directly!
    browserdisplay::BrowserDisplay
end

function EWindow(args...)
    app = Electron().Application(;
        additional_electron_args=[
            "--no-sandbox",
            "--enable-logging",
            "--user-data-dir=$(mktempdir())",
            "--disable-features=AccessibilityObjectModel",
            "--enable-unsafe-swiftshader",        # ← allow SwiftShader fallback
            "--use-gl=swiftshader",               # ← explicitly request software GL
            "--disable-gpu",                      # ← disable GPU to avoid GPU errors
        ],
    )
    return Electron().Window(app, args...)
end

function ElectronDisplay(; devtools = false)
    w = EWindow()
    devtools && Electron().toggle_devtools(w)
    return ElectronDisplay(w, BrowserDisplay(; open_browser=false))
end

Base.displayable(d::ElectronDisplay, ::MIME{Symbol("text/html")}) = true

function Base.display(display::ElectronDisplay, app::App)
    needs_load = Base.display(display.browserdisplay, app)
    url = online_url(display.browserdisplay)
    if needs_load
        Electron().load(display.window, URI(url))
    end
    wait_for_ready(app)
    return display
end

function use_electron_display(; devtools = false)
    disp = ElectronDisplay(; devtools = devtools)
    filter!(x-> !(x isa ElectronDisplay), Base.Multimedia.displays)
    Base.Multimedia.pushdisplay(disp)
    return disp
end

function Base.close(display::ElectronDisplay)
    isopen(display.window) && close(display.window)
    close(display.browserdisplay)
    return nothing
end
