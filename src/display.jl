struct Page
    serializer::UrlSerializer
    with_julia_server::Bool
    session::Session
    child_sessions::Dict{String, Session}
end

const CURRENT_PAGE = Ref{Page}()

function Page()
    p = Page(UrlSerializer(), true, Session(), Dict{String, Session}())
    CURRENT_PAGE[] = p
    return p
end

function Base.show(io::IO, ::MIME"text/html", page::Page)
    server = get_server()
    server.sessions[page.session.id] = page.session
    serializer = page.serializer
    websocket_url = JSSERVE_CONFIGURATION.external_url[]
    delete_session = Observable("")

    push!(page.session, page.session.js_comm)

    on(delete_session) do session_id
        println("DELETING SESSION: $(session_id)")
        if !haskey(page.child_sessions, session_id)
            error("Session to delete not found ($(session_id)), please open an issue with JSServe.jl")
        end
        child = page.child_sessions[session_id]
        child.connection[] = nothing
        close(child)
        delete!(page.child_sessions, session_id)
    end
    @info("Page session: $(page.session.id)")
    page_init_dom = DOM.div(
        include_asset(PakoLib, serializer),
        include_asset(MsgPackLib, serializer),
        include_asset(JSServeLib.assets[1], serializer),
        js"""

            window.session_dom_nodes = new Set()
            const observer = new MutationObserver(function(mutations) {
                let removal_occured = false
                const to_delete = new Set()
                mutations.forEach(mutation=>{
                    mutation.removedNodes.forEach(x=> {
                        if (x.id && session_dom_nodes.has(x.id)) {
                            to_delete.add(x.id)
                        } else {
                            removal_occured = true
                        }
                    })
                })
                // removal occured from elements not matching the id!
                if (removal_occured) {
                    window.session_dom_nodes.forEach(id=>{
                        if (!document.getElementById(id)) {
                            to_delete.add(id)
                        }
                    })
                }
                to_delete.forEach(id=>{
                    window.session_dom_nodes.delete(id)
                    JSServe.update_obs($(delete_session), id)
                })
            });

            observer.observe(document, {attributes: false, childList: true, characterData: false, subtree: true});
            const proxy_url = $(websocket_url)
            const session_id = $(page.session.id)
            JSServe.setup_connection({proxy_url, session_id})
            JSServe.sent_done_loading()
        """
    )
    println(io, node_html(page.session, page_init_dom))
end

function assure_ready(session)
    Base.timedwait(30.0) do
        isopen(session) && isready(session.js_fully_loaded)
    end
    messages = fused_messages!(session)
    @info("Sending fused messages: $(length(messages))")
    send(session, messages)
end

function Base.show(io::IO, m::Union{MIME"text/html", MIME"application/prs.juno.plotpane+html"}, app::App)
    if !isassigned(CURRENT_PAGE)
        error("Please initialize Page rendering by running JSServe.Page()")
    end

    page = CURRENT_PAGE[]
    page_session = page.session

    session = Session(page_session;
        connection=Base.RefValue{Union{Nothing, WebSocket}}(nothing),
        dependencies=Set{Asset}(),
        id=string(uuid4()),
        observables=Dict{String, Tuple{Bool, Observable}}(),
        on_close=Observable(false),
        message_queue=Dict{Symbol, Any}[],
        deregister_callbacks=Observables.ObserverFunction[]
    )
    # register with page session for proper clean up!
    page.child_sessions[session.id] = session

    # The page session must be ready to display anything!
    # Since the page display is rendered async in the browser and we have no
    # idea when it's done on the Julia side, so we need to wait here!
    assure_ready(page_session)

    on_init = Observable(false)
    push!(page_session, on_init)

    html_dom = Base.invokelatest(app.handler, session, (; show="/show"))
    js_dom = jsrender(session, html_dom)
    register_resource!(session, js_dom)

    obs_shared_with_parent = intersect(keys(session.observables), keys(page_session.observables))
    # Those obs are managed by page session, so we don't need to have them in here!
    @info("Length of shared: $(length(obs_shared_with_parent))")
    for obs in obs_shared_with_parent
        delete!(session.observables, obs)
    end

    # no
    merge!(page_session.observables, session.observables)

    new_deps = setdiff(session.dependencies, page_session.dependencies)
    union!(page_session.dependencies, new_deps)

    init_script = js"""
        JSServe.update_obs($(on_init), true)
        console.log(session_dom_nodes)
        window.session_dom_nodes.add($(session.id))
    """

    final_dom = DOM.div(
        js_dom,
        include_asset.(new_deps, (page_session.url_serializer,))...,
        jsrender(session, init_script),
        id=session.id
    )

    html = repr(MIME"text/html"(), Hyperscript.Pretty(final_dom))

    messages = fused_messages!(session)

    session.connection[] = page_session.connection[]
    push!(session, page_session.js_comm)

    on(on_init) do is_init
        @info("Initialized, sending $(length(messages)) messages")
        if !is_init
            error("The html didn't initialize correctly")
        end
        send(page_session, messages)
    end
    on(session.on_close) do closed
        # remove the sub-session specific js resources
        if closed
            obs_ids = collect(keys(session.observables))
            @info("Deleting all them observables: $(length(obs_ids))")
            JSServeLib.delete_observables(page_session, obs_ids)
        end
    end
    println(io, html)
end

function iframe_html(server::Server, session::Session, route::String)
    # Display the route we just added in an iframe inline:
    url = repr(online_url(server, route))
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
        """,
        DOM.iframe(src=url, id=session.id, style=style, scrolling="no")
    )
end

function page_html(session::Session, app::App)
    proxy_url = JSSERVE_CONFIGURATION.external_url[]
    html = app_html(session, app)
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
    $(include_asset(PakoLib, serializer))
    $(include_asset(MsgPackLib, serializer))
    $(include_asset(JSServeLib, serializer))
    </head>
    <body onload=sent_done_loading()>
        $(html)
    </body>
    </html>
    """
end

function node_html(session::Session, node::Hyperscript.Node)
    js_dom = DOM.div(jsrender(session, node), id="application-dom")
    # register resources (e.g. observables, assets)
    register_resource!(session, js_dom)
    return repr(MIME"text/html"(), Hyperscript.Pretty(js_dom))
end

function app_html(session::Session, app::App)
    js_dom = DOM.div(jsrender(session, app), id="application-dom")
    # register resources (e.g. observables, assets)
    register_resource!(session, js_dom)
    return repr(MIME"text/html"(), Hyperscript.Pretty(js_dom))
end

function show_in_iframe(server, session, app)
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
        on_document_load(session, js"JSServe.resize_iframe_parent($(session.id))")
        html_dom = Base.invokelatest(app.handler, session, request)
        return html(page_html(session, html_dom))
    end
    return iframe_html(server, session, session_route)
end

function show_inline(session::Session, app::App)
    dom = Base.invokelatest(app.handler, session, (target = "/show_inline",))
    return app_html(session, dom)
end

# function Base.show(io::IO, m::Union{MIME"text/html", MIME"application/prs.juno.plotpane+html"}, app::App)
#     server = get_server()
#     session = Session()
#     println(io, show_in_iframe(server, session, app))
# end

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
