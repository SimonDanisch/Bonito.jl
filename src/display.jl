const GLOBAL_SERVER = Ref{Server}()

function get_server()
    if !isassigned(GLOBAL_SERVER) || istaskdone(GLOBAL_SERVER[].server_task[])
        GLOBAL_SERVER[] = Server(
            App("Nothing to see"),
            JSSERVE_CONFIGURATION.listen_url[],
            JSSERVE_CONFIGURATION.listen_port[],
            verbose=JSSERVE_CONFIGURATION.verbose[]
        )
    end
    return GLOBAL_SERVER[]
end

const WebMimes = (
    MIME"text/html",
    MIME"application/prs.juno.plotpane+html",
)

function iframe_html(server::Server, session::Session, route::String)
    # Display the route we just added in an iframe inline:
    url = repr(local_url(server, route))
    remote_origin = local_url(server, "")
    style = "position: relative; display: block; width: 100%; height: 100%; padding: 0; overflow: hidden; border: none"
    return """
    <script>
        function register_resize_handler(remote_origin) {
            function resize_callback(event) {
                if (event.origin !== remote_origin) {
                    return;
                }
                console.log("resizing")
                const uuid = event.data[0];
                const width = event.data[1];
                const height = event.data[2];
                console.log(width)
                console.log(height)
                console.log(uuid)
                const iframe = document.getElementById(uuid);
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
        register_resize_handler($(repr(remote_origin)))
    </script>
    <iframe src=$(url) id="$(session.id)" style="$(style)" scrolling="no">
    </iframe>
    """
end

for M in WebMimes
    @eval function Base.show(io::IO, m::$M, app::App)
        println("####################################################")
        server = get_server()
        session = Session()
        session_route = "/$(session.id)"
        # Our default is to display the app in an IFrame, which is a bit complicated
        # we need to resize the iframe based on its content, which is a bit complicated
        # because we can't directly access it. So we sent a message here
        # to the parent iframe, for which we register an
        # event handler via resize_iframe_parent, which then
        # resizes the parent iframe accordingly
        route!(server, session_route) do context
            application = context.application
            request = context.request
            application.sessions[session.id] = session
            on_document_load(session, js"resize_iframe_parent($(session.id))")
            html_dom = Base.invokelatest(app.handler, session, request)
            return html(dom2html(session, html_dom))
        end
        println(io, iframe_html(server, session, session_route))
    end
end

function Base.show(io::IO, ::MIME"application/vnd.webio.application+html", dom::App)
    application = get_server()
    session = Session()
    application.sessions[session.id] = session
    dom = Base.invokelatest(dom.handler, session, (target = "/show",))
    println(io, dom2html(session, dom))
end

function dom2html(session::Session, app)
    js_dom = DOM.div(jsrender(session, app), id="application-dom")
    # register resources (e.g. observables, assets)
    register_resource!(session, js_dom)
    proxy_url = JSSERVE_CONFIGURATION.websocket_proxy[]
    html = repr(MIME"text/html"(), Hyperscript.Pretty(js_dom))
    serializer = session.url_serializer
    return """
    <html>
    <head>
    <meta charset="UTF-8">
    $(include_asset(session.dependencies, serializer))
    <script>
        window.js_call_session_id = '$(session.id)';
        window.websocket_proxy_url = '$(proxy_url)';
    </script>
    $(include_asset(MsgPackLib, serializer))
    $(include_asset(JSCallLibLocal, serializer))
    </head>
    <body onload=sent_done_loading()>
        $(html)
    </body>
    </html>
    """
end

function Base.show(io::IOContext, m::MIME"application/vnd.jsserve.application+html", dom::App)
    if get(io, :use_offline_mode, false)
        export_folder = get(io, :export_folder, "/")
        absolute_urls = get(io, :absolute_urls, false)
        content_delivery_url = get(io, :content_delivery_url, "")
        html, session = export_standalone(dom.handler, export_folder;
            absolute_urls=absolute_urls,
            content_delivery_url=content_delivery_url,
            write_index_html=false)
        # We prepare for being offline, but we still start a server while things
        # are online!
        application = get_server()
        application.sessions[session.id] = session
        println(io, html)
    else
        show(io.io, m, dom)
    end
end

function Base.show(io::IO, ::MIME"application/vnd.jsserve.application+html", app::App)
    show(IOContext(io), MIME"text/html"(), app)
end

function Base.show(io::IO, ::MIME"juliavscode/html", app::App)
    show(IOContext(io), MIME"text/html"(), app)
end
