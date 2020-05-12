
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
    html_str = """
    <html>
    <head>
    <meta charset="UTF-8">
    $(include_asset(session.dependencies))
    <script>
        window.js_call_session_id = '$(session.id)';
        window.websocket_proxy_url = '$(proxy_url)';
    </script>
    $(include_asset(MsgPackLib))
    $(include_asset(JSCallLibLocal))
    <script>
    function __on_document_load__(){
        $(queued_as_script(session))
    };
    </script>
    </head>
    <body onload=__on_document_load__()>
        $(html)
    </body>
    </html>
    """
    # Empty on_document_load, so we can make a diff when things get dynamically loaded
    # into on_document_load
    empty!(session.dependencies)
    empty!(session.on_document_load)
    return html_str
end

"""
export_standalone(dom_handler, folder::String;
        absolute_urls=false, content_delivery_url="file://" * folder * "/",
    )

Exports the app defined by `dom_handler` with all its assets to `folder`.
Will write the main html out into `folder/index.html`.
Overwrites all existing files!
If this gets served behind a proxy, set `absolute_urls=true` and
set `content_delivery_url` to your proxy url.
If `clear_folder=true` all files in `folder` will get deleted before exporting again!
"""
function export_standalone(dom_handler, folder::String;
        clear_folder=false, write_index_html=true,
        absolute_urls=false, content_delivery_url="file://" * folder * "/",
    )
    if clear_folder
        for file in readdir(folder)
            rm(joinpath(folder, file), force=true, recursive=true)
        end
    end
    serializer = UrlSerializer(false, folder, absolute_urls, content_delivery_url)
    # set id to "", since we dont needed, and like this we get nicer file names
    session = Session(url_serializer=serializer, id="standalone")
    html_dom = Base.invokelatest(dom_handler, session, (target="/",))
    js_dom = DOM.div(jsrender(session, html_dom), id="application-dom")
    # register resources (e.g. observables, assets)
    register_resource!(session, js_dom)
    html = repr(MIME"text/html"(), Hyperscript.Pretty(js_dom))
    html_str = """
    <html>
    <head>
    $(include_asset(session.dependencies, serializer))
    <script>
        window.js_call_session_id = null;
        window.websocket_proxy_url = null;
    </script>
    $(include_asset(MsgPackLib, serializer))
    $(include_asset(JSCallLibLocal, serializer))
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
    if write_index_html
        open(joinpath(folder, "index.html"), "w") do io
            println(io, html_str)
        end
    else
        return html_str
    end
end


function Base.show(io::IOContext, m::MIME"application/vnd.jsserve.application+html", dom::DisplayInline)
    if get(io, :use_offline_mode, false)
        export_folder = get(io, :export_folder, "/")
        absolute_urls = get(io, :absolute_urls, false)
        content_delivery_url = get(io, :content_delivery_url, "")
        html = export_standalone(dom.dom_function, export_folder; absolute_urls=absolute_urls,
                          content_delivery_url=content_delivery_url,
                          write_index_html=false)
        println(io, html)
    else
        show(io.io, m, dom)
    end
end

function Base.show(io::IO, m::MIME"application/vnd.jsserve.application+html", dom::DisplayInline)
    show(io.io, MIME"text/html"(), dom)
end
