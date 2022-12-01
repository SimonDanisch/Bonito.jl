Base.showable(::Union{MIME"text/html", MIME"application/prs.juno.plotpane+html"}, ::App) = true

const CURRENT_SESSION = Ref{Union{Nothing, Session}}(nothing)

function Page()
    old_session = CURRENT_SESSION[]
    if !isnothing(old_session)
        close(old_session)
    end
    CURRENT_SESSION[] = nothing
    return
end

function Base.show(io::IO, m::Union{MIME"text/html", MIME"application/prs.juno.plotpane+html"}, app::App)
    if !isnothing(CURRENT_SESSION[])
        # We render in a subsession
        parent = CURRENT_SESSION[]
        sub = Session(parent)
        dom = session_dom(sub, app)
    else
        session = Session()
        if _use_parent_session(session)
            CURRENT_SESSION[] = session
            empty_app = App(()-> nothing)
            sub = Session(session)
            init_dom = session_dom(session, empty_app)
            sub_dom = session_dom(sub, app)
            # first time rendering in a subsession, we combine init of parent session
            # with the dom we're rendering right now
            dom = DOM.div(init_dom, sub_dom)
        else
            sub = session
            dom = session_dom(session, app)
        end
    end
    show(io, Hyperscript.Pretty(dom))
    return sub
end

function node_html(io::IO, session::Session, node::Hyperscript.Node)
    js_dom = DOM.div(jsrender(session, node), id="application-dom")
    return show(io, MIME"text/html"(), Hyperscript.Pretty(js_dom))
end

"""
    page_html(session::Session, html_body)

Embeds the html_body in a standalone html document!
"""
function page_html(io::IO, session::Session, app_node::Union{Node, App})
    dom = session_dom(session, app_node)
    println(io, "<!doctype html>")
    show(io, MIME"text/html"(), Hyperscript.Pretty(dom))
    return
end

function Base.show(io::IOContext, m::MIME"application/vnd.jsserve.application+html", dom::App)
    show(io.io, MIME"text/html"(), dom)
end

function Base.show(io::IO, m::MIME"application/vnd.jsserve.application+html", app::App)
    show(IOContext(io), m, app)
end

function Base.show(io::IO, ::MIME"juliavscode/html", app::App)
    show(IOContext(io), MIME"text/html"(), app)
end
