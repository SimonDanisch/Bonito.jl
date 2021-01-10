struct Page
    serializer::UrlSerializer
    with_julia_server::Bool
    session::Session
    child_sessions::Dict{String, Session}
end

const CURRENT_PAGE = Ref{Page}()

function Page(;session = Session())
    p = Page(UrlSerializer(), true, session, Dict{String, Session}())
    CURRENT_PAGE[] = p
    return p
end

function Base.show(io::IO, ::MIME"text/html", page::Page)
    server = get_server()
    insert_session!(server, page.session)
    serializer = page.serializer
    websocket_url = JSSERVE_CONFIGURATION.external_url[]
    delete_session = Observable("")

    push!(page.session, page.session.js_comm)

    on(delete_session) do session_id
        if !haskey(page.child_sessions, session_id)
            error("Session to delete not found ($(session_id)), please open an issue with JSServe.jl")
        end

        @debug("deleting child session: $(session_id)")
        child = page.child_sessions[session_id]
        # Set connection to nothing,
        # so that no clean up happens over the active websocket connection
        # (e.g. close will try to close the ws connection)
        child.on_close[] = true
        child.connection[] = nothing
        close(child)
        delete!(page.child_sessions, session_id)
    end

    page_init_dom = DOM.div(
        include_asset(PakoLib, serializer),
        include_asset(MsgPackLib, serializer),
        include_asset(JSServeLib, serializer),
        js"""
            const proxy_url = $(websocket_url)
            const session_id = $(page.session.id)
            // track if our child session doms get removed from the document (dom)
            JSServe.track_deleted_sessions($(delete_session))
            JSServe.setup_connection({proxy_url, session_id})
            JSServe.sent_done_loading()
        """
    )
    println(io, node_html(page.session, page_init_dom))
end

function assure_ready(page::Page)
    session = page.session
    filter!(page.child_sessions) do (id, session)
        never_opened = isnothing(session.connection[])
        if never_opened
            @warn("Removing unopened Session: $(id)")
            close(session)
        end
        return !never_opened
    end
    Base.timedwait(30.0) do
        return isready(session) && all(((id, s),)-> isready(s), page.child_sessions)
    end
    send(session, fused_messages!(session))
end

function show_in_page(page::Page, app::App)
    page_session = page.session
    # The page session must be ready to display anything!
    # Since the page display is rendered async in the browser and we have no
    # idea when it's done on the Julia side, so we need to wait here!
    assure_ready(page)

    # Create a child session, to track the per app resources
    session = Session(page_session;
        connection=Base.RefValue{Union{Nothing, WebSocket, IOBuffer}}(nothing),
        dependencies=Set{Asset}(),
        id=string(uuid4()),
        observables=Dict{String, Tuple{Bool, Observable}}(),
        on_close=Observable(false),
        message_queue=Dict{Symbol, Any}[],
        js_fully_loaded=Channel{Bool}(1),
        deregister_callbacks=Observables.ObserverFunction[]
    )
    # register with page session for proper clean up!
    page.child_sessions[session.id] = session



    on_init = Observable(false)
    # Manually register on_init - this is a bit fragile, but
    # we need to normally register on_init with `session`, BUT
    # it already needs to be registered upfront with JSServe in the browser
    # so that it can properly trigger the observable early in the loaded html/js
    send(page_session, payload=on_init[], id=on_init.id, msg_type=RegisterObservable)
    # Render the app and register all the resources with the session
    # Note, since we set the connection to nothing, nothing gets sent yet
    # This is important, since we can only sent the messages after the HTML has been rendered
    # since we must assume the messages / js contains references to HTML elements
    html_dom = Base.invokelatest(app.handler, session, (; show="/show_inline"))
    js_dom = jsrender(session, html_dom)
    register_resource!(session, js_dom)

    new_deps = setdiff(session.dependencies, page_session.dependencies)
    union!(page_session.dependencies, new_deps)

    init_script = js"""
        JSServe.update_obs($(on_init), true)
        // register this session so it gets deleted when it gets removed from dom
        JSServe.register_sub_session($(session.id))
    """

    final_dom = DOM.div(
        js_dom,
        include_asset.(new_deps, (page_session.url_serializer,))...,
        jsrender(session, init_script),
        id=session.id
    )

    obs_shared_with_parent = intersect(keys(session.observables), keys(page_session.observables))
    # Those obs are managed by page session, so we don't need to have them in here!
    # This is important when we clean them up, since a child session shouldn't
    # delete any observable already managed by the parent session
    for obs in obs_shared_with_parent
        delete!(session.observables, obs)
    end
    # but in the end, all observables need to be registered
    # with the page session, since that's where javascript will sent all the events
    merge!(page_session.observables, session.observables)

    # We take all
    messages = fused_messages!(session)

    session.connection[] = page_session.connection[]
    on(session, on_init) do is_init
        if !is_init
            error("The html didn't initialize correctly")
        end
        put!(session.js_fully_loaded, true)
        @debug("initializing child session: $(session.id)")
        send(session, messages)
    end

    on(session, session.on_close) do closed
        # remove the sub-session specific js resources
        if closed
            obs_ids = collect(keys(session.observables))
            JSServeLib.delete_observables(page_session, obs_ids)
            # since we deleted all obs shared with the parent session,
            # we can delete savely delete all of them from there
            # Note, that we previously added them all here!
            for (k, o) in session.observables
                delete!(page_session.observables, k)
            end
        end
    end

    return repr(MIME"text/html"(), Hyperscript.Pretty(final_dom))
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
        server = context.application
        request = context.request
        insert_session!(server, session)
        on_document_load(session, js"JSServe.resize_iframe_parent($(session.id))")
        html_dom = Base.invokelatest(app.handler, session, request)
        return html(page_html(session, html_dom))
    end
    return jsrender(session, iframe_html(server, session, session_route))
end

function Base.show(io::IO, m::Union{MIME"text/html", MIME"application/prs.juno.plotpane+html"}, app::App)
    if isassigned(CURRENT_PAGE)
        # We are in Page rendering mode!
        page = CURRENT_PAGE[]
        println(io, show_in_page(page, app))
    else
        server = get_server()
        session = Session()
        println(io, show_in_iframe(server, session, app))
    end
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

function node_html(session::Session, node::Hyperscript.Node)
    js_dom = DOM.div(jsrender(session, node), id="application-dom")
    # register resources (e.g. observables, assets)
    register_resource!(session, js_dom)
    return repr(MIME"text/html"(), Hyperscript.Pretty(js_dom))
end


"""
    page_html(session::Session, html_body)
Embedds the html_body in a standalone html document!
"""
function page_html(session::Session, html)
    proxy_url = JSSERVE_CONFIGURATION.external_url[]

    serializer = session.url_serializer
    session_deps = include_asset.(session.dependencies, (serializer,))
    rendered = jsrender(session, html)
    register_resource!(session, rendered)
    html_body = DOM.html(
        DOM.head(
            DOM.meta(charset="UTF-8"),
            include_asset(session.dependencies, serializer),
            include_asset(PakoLib, serializer),
            include_asset(MsgPackLib, serializer),
            include_asset(JSServeLib, serializer),
            session_deps...
        ),
        DOM.body(
            DOM.div(rendered, id="application-dom"),
            onload=DontEscape("""
                const proxy_url = '$(proxy_url)'
                const session_id = '$(session.id)'
                JSServe.setup_connection({proxy_url, session_id})
                JSServe.sent_done_loading()
            """)
        )
    )
    return repr(MIME"text/html"(), Hyperscript.Pretty(html_body))
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
        show(io.io, MIME"text/html"(), dom)
    end
end

function Base.show(io::IO, m::MIME"application/vnd.jsserve.application+html", app::App)
    show(IOContext(io), m, app)
end

function Base.show(io::IO, ::MIME"juliavscode/html", app::App)
    show(IOContext(io), MIME"text/html"(), app)
end
