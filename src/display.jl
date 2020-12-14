
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

function resize_iframe_event_handler(app)
    remote_origin = JSServe.local_url(app, "")
    js"""
    function resize_jsserve_iframe(event) {
       if (event.origin !== $(remote_origin)) {
           return;
       }
       const uuid = event.data[0];
       const width = event.data[1];
       const height = event.data[2];
       const iframe = document.getElementById(uuid);
       if (iframe) {
           iframe.style.width = width + "px";
           iframe.style.height = height + "px";
       }
    };
    if (window.addEventListener) {
       window.addEventListener("message", resize_jsserve_iframe, false);
    } else if (window.attachEvent) {
       window.attachEvent("onmessage", resize_jsserve_iframe);
    }
    """
end

for M in WebMimes
    @eval function Base.show(io::IO, m::$M, dom::DisplayInline)
        is_this_first_time = isassigned(global_application)
        application = get_global_app()
        session = Session()
        session_url = "/$(session.id)"
        route!(application, session_url) do context
            # Serve the actual content
            application = context.application
            application.sessions[session.id] = session
            html_dom = Base.invokelatest(dom.dom_function, session, context.request)
            resize_script = js"""
                // we need to resize the iframe based on its content, which is a bit complicated
                // because we can't directly access it. So we sent a message here
                // to the parent iframe, for which we register an
                // event handler via resize_iframe_event_handler, which then
                // resizes the parent iframe accordingly
                {
                    (function (){
                        const body = document.body;
                        const html = document.documentElement;
                        const height = Math.max(body.scrollHeight, body.offsetHeight,
                                                html.clientHeight, html.scrollHeight,
                                                html.offsetHeight);
                        const width = Math.max(body.scrollWidth, body.offsetWidth,
                                               html.clientWidth, html.scrollHeight,
                                               html.offsetWidth);
                        if (parent.postMessage) {
                            parent.postMessage([$(session.id), width, height], "*");
                        }
                    })()
                }
            """
            on_document_load(session, resize_script)
            return html(dom2html(session, html_dom))
        end
        # Display the route we just added in an iframe inline:
        url = repr(local_url(application, session_url))
        style = "position: relative; display: block; width: 100%; height: 100%; padding: 0; overflow: hidden; border: none"
        println(io, """
        <iframe src=$(url) id="$(session.id)" style="$(style)" scrolling="no">
        </iframe>
        """)
        # When this is called for the first time, we need to register
        # a resize handler for the iframes
        # This is global, so doesn't need to be done every time
        if is_this_first_time
            println(io, """
            <script>
            $(resize_iframe_event_handler(application))
            </script>
            """)
        end
    end
end

function Base.show(io::IO, ::MIME"application/vnd.webio.application+html", dom::DisplayInline)
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

function Base.show(io::IOContext, m::MIME"application/vnd.jsserve.application+html", dom::DisplayInline)
    if get(io, :use_offline_mode, false)
        export_folder = get(io, :export_folder, "/")
        absolute_urls = get(io, :absolute_urls, false)
        content_delivery_url = get(io, :content_delivery_url, "")

        html, session = export_standalone(dom.dom_function, export_folder;
            absolute_urls=absolute_urls,
            content_delivery_url=content_delivery_url,
            write_index_html=false)
        # We prepare for being offline, but we still start a server while things
        # are online!
        application = get_global_app()
        application.sessions[session.id] = session

        println(io, html)
    else
        show(io.io, m, dom)
    end
end

function Base.show(io::IO, ::MIME"application/vnd.jsserve.application+html", dom::DisplayInline)
    show(IOContext(io), MIME"text/html"(), dom)
end

function Base.show(io::IO, ::MIME"juliavscode/html", dom::DisplayInline)
    show(IOContext(io), MIME"text/html"(), dom)
end
