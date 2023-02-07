using JSServe: URI

mutable struct BrowserDisplay <: Base.Multimedia.AbstractDisplay
    server::Union{Nothing, Server}
    open_browser::Bool
end

BrowserDisplay(; open_browser=true) = BrowserDisplay(nothing, open_browser)

function server(bd::BrowserDisplay)
    if isnothing(bd.server)
        bd.server = get_server()
    end
    return bd.server
end

"""
    browser_display()
Forces JSServe.App to be displayed in a browser window that gets opened.
"""
function browser_display()
    displays = Base.Multimedia.displays
    if last(displays) isa BrowserDisplay
        @info("already in there!")
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
        tryrun(`open $url`) && return
    elseif Sys.iswindows()
        tryrun(`powershell.exe start $url`) && return
    elseif Sys.isunix()
        tryrun(`xdg-open $url`) && return
        tryrun(`gnome-open $url`) && return
    end
    tryrun(`python -mwebbrowser $(url)`) && return
    # our last hope
    tryrun(`python3 -mwebbrowser $(url)`) && return
    @warn("Can't find a way to open a browser, open $(url) manually!")
end

function Base.display(display::BrowserDisplay, app::App)
    _server = server(display)
    session_url = "/browser-display"
    old_app = route!(_server, Pair{Any,Any}(session_url, app))
    if isnothing(old_app) || isnothing(old_app.session[]) || !isready(old_app.session[])
        if !isnothing(old_app) && !isnothing(old_app.session[]) # Not ready!
            close(old_app.session[])
        end
        if display.open_browser
            openurl(online_url(_server, session_url))
        end
        return true
    else
        update_app!(old_app, app)
        return false
    end
    return
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

function ElectronDisplay()
    w = Electron().Window()
    Electron().toggle_devtools(w)
    return ElectronDisplay(w, BrowserDisplay(; open_browser=false))
end

Base.displayable(d::ElectronDisplay, ::MIME{Symbol("text/html")}) = true

function Base.display(display::ElectronDisplay, app::App)
    needs_load = Base.display(display.browserdisplay, app)
    url = online_url(display.browserdisplay)
    if needs_load
        Electron().load(display.window, URI(url))
    end
    return display
end

function use_electron_display()
    disp = ElectronDisplay()
    Base.Multimedia.pushdisplay(disp)
    return disp
end
