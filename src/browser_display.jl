struct BrowserDisplay <: Base.Multimedia.AbstractDisplay end

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

function Base.display(::BrowserDisplay, dom::App)
    application = get_server()
    session_url = "/browser-display"
    route_was_present = route!(application, session_url) do context
        # Serve the actual content
        session = insert_session!(context.application)
        html_dom = Base.invokelatest(dom.handler, session, context.request)
        return html(page_html(session, html_dom))
    end
    # Only open url first time!
    if isempty(application.sessions)
        openurl(online_url(application, session_url))
    else
        for (id, session) in application.sessions
            evaljs(session, js"location.reload(true)")
        end
    end
    return
end
