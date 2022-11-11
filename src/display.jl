
const CURRENT_SESSION = Ref{Session}()


function show_in_iframe(server, session, app)
    session_route = "/$(session.id)"
    # Our default is to display the app in an IFrame, which is a bit complicated
    # we need to resize the iframe based on its content, which is a bit complicated
    # because we can't directly access it. So we sent a message here
    # to the parent iframe, for which we register an
    # event handler via resize_iframe_parent, which then
    # resizes the parent iframe accordingly
    app_wrapped = App() do session::Session, request
        on_document_load(session, js"JSServe.resize_iframe_parent($(session.id))")
        html_dom = Base.invokelatest(app.handler, session, request)
        return html_dom
    end
    route!(server, session_route => app_wrapped)
    return jsrender(session, iframe_html(server, session, session_route))
end

Base.showable(::Union{MIME"text/html", MIME"application/prs.juno.plotpane+html"}, ::App) = true

function Base.show(io::IO, m::Union{MIME"text/html", MIME"application/prs.juno.plotpane+html"}, app::App)
    if isassigned(CURRENT_SESSION)
        # We render in a subsession
        session = Session(CURRENT_SESSION[])
    else
        session = Session()
        if use_parent_session(session)
            CURRENT_SESSION[] = session
        end
    end
    domy = JSServe.session_dom(session, app)
    show(io, Hyperscript.Pretty(domy))
end

function iframe_html(server::Server, session::Session, route::String)
    # Display the route we just added in an iframe inline:
    url = online_url(server, route)
    remote_origin = online_url(server, "")
    style = "position: relative; display: block; width: 100%; height: 100%; padding: 0; overflow: hidden; border: none"
    return DOM.div(
        js"""
            function register_resize_handler(remote_origin) {
                function resize_callback(event) {
                    if (event.origin !== remote_origin) {
                        return;
                    }
                    const uuid = event.data[0];
                    const width = event.data[1];
                    const height = event.data[2];
                    const iframe = document.getElementById($(session.id));
                    if (iframe) {
                        iframe.style.width = width + "px";
                        iframe.style.height = height + "px";
                    }
                }
                if (window.addEventListener) {
                    window.addEventListener("message", resize_callback, false);
                } else if (window.attachEvent) {
                    window.attachEvent("onmessage", resize_callback);
                }
            }
            register_resize_handler($(remote_origin))
        """,
        DOM.iframe(src=url, id=session.id, style=style, scrolling="no")
    )
end

function node_html(io::IO, session::Session, node::Hyperscript.Node)
    js_dom = DOM.div(jsrender(session, node), id="application-dom")
    return show(io, MIME"text/html"(), Hyperscript.Pretty(js_dom))
end

"""
    page_html(session::Session, html_body)
Embeds the html_body in a standalone html document!
"""
function page_html(io::IO, session::Session, app::App)
    dom = session_dom(session, app)
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

function show_as_html(io::IO, session::Session, dom)
    println(io, "<!doctype html>")
    show(io, MIME"text/html"(), Hyperscript.Pretty(html_body))
end
