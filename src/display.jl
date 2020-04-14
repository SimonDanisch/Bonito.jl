
const global_application = Ref{Application}()


struct DisplayInline
    dom_function
end


"""
    with_session(f)::DisplayInline

calls f with the session, that will become active when displaying the result
of with_session. f is expected to return a valid DOM.
"""
function with_session(f)
    return DisplayInline(f)
end

const WebMimes = (
    MIME"text/html",
    MIME"application/prs.juno.plotpane+html",
    # MIME"application/vnd.webio.application+html"
)

function get_global_app()
    if !isassigned(global_application) || istaskdone(global_application[].server_task[])
        global_application[] = Application(
            (ctx, request)-> "Nothing to see",
            JSSERVE_CONFIGURATION.listen_url[],
            JSSERVE_CONFIGURATION.listen_port[],
            verbose=JSSERVE_CONFIGURATION.verbose[]
        )
    end
    return global_application[]
end

for M in WebMimes
    @eval function Base.show(io::IO, m::$M, dom::DisplayInline)
        application = get_global_app()
        session_url = "/show"
        route!(application, session_url) do context
            # Serve the actual content
            return serve_dom(context, dom.dom_function)
        end
        # Display the route we just added in an iframe inline:
        url = repr(local_url(application, session_url))
        println(io, "<iframe src=$(url) style=\"position: absolute; height: 100%; width: 100%;border: none\">")
        println(io, "</iframe>")
    end
end

function Base.show(io::IO, m::MIME"application/vnd.webio.application+html", dom::DisplayInline)
    application = get_global_app()
    session = Session()
    application.sessions[session.id] = session
    dom = Base.invokelatest(dom.dom_function, session, (target = "/show",))
    println(io, dom2html(session, dom))
end

function dom2html(session::Session, dom)
    js_dom = DOM.div(jsrender(session, dom), id="application-dom")
    # register resources (e.g. observables, assets)
    register_resource!(session, js_dom)
    proxy_url = JSSERVE_CONFIGURATION.websocket_proxy[]
    html = repr(MIME"text/html"(), Hyperscript.Pretty(js_dom))
    return """
    <html>
    <head>
    $(serialize_readable(session.dependencies))
    <script>
        window.js_call_session_id = '$(session.id)';
        window.websocket_proxy_url = '$(proxy_url)';
    </script>
    $(serialize_readable(MsgPackLib))
    $(serialize_readable(JSCallLibLocal))
    <script>
    function __on_document_load__(){
        $(queued_as_script(session))

        $(serialize_readable(session.on_document_load))
    };
    </script>
    </head>
    <body onload=__on_document_load__()>
        $(html)
    </body>
    </html>
    """
end
