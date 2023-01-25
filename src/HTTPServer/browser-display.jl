mutable struct BrowserDisplay <: Base.Multimedia.AbstractDisplay
    server::Union{Nothing, Server}
end

BrowserDisplay() = BrowserDisplay(nothing)

function server(bd::BrowserDisplay)
    if isnothing(bd.server)
        bd.server = get_server()
    end
    return bd.server
end

"""
    browser_display()
Forces Dashi.App to be displayed in a browser window that gets opened.
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

function Base.display(bd::BrowserDisplay, app::App)
    _server = server(bd)
    session_url = "/browser-display"
    old_app = route!(_server, Pair{Any,Any}(session_url, app))
    if isnothing(old_app) || isnothing(old_app.session[]) || !isready(old_app.session[])
        openurl(online_url(_server, session_url))
    else
        update_app!(old_app, app)
    end
    return
end

function has_html_display()
    for display in Base.Multimedia.displays
        # Ugh, why would textdisplay say it supports HTML??
        display isa TextDisplay && continue
        displayable(display, MIME"text/html"()) && return true
    end
    return false
end
