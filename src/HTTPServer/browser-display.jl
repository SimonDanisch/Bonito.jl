struct BrowserDisplay <: Base.Multimedia.AbstractDisplay
    server::Server
end

BrowserDisplay() = BrowserDisplay(get_server())

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

function Base.display(bd::BrowserDisplay, dom)
    server = bd.server
    session_url = "/browser-display"
    is_new_route = route!(server, session_url) do context
        html_str = sprint() do io
            show(io, MIME"text/html"(), dom)
        end
        return html(html_str)
    end
    if is_new_route
        openurl(online_url(server, session_url))
    else

    end
    return
end
