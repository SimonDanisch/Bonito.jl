struct Page
    session::Session
    child_sessions::Dict{String, Session}

    # Inlines all CSS & JS dependencies, and doesn't use websocket connection
    # to load initial data. This makes JSServe a bit slower, but allows you do
    # export the Page to static HTML e.g. in Pluto
    exportable::Bool
    # Doesn't even try to connect to a julia process
    offline::Bool
end

const CURRENT_PAGE = Ref{Page}()

"""
    Page(;
        session=nothing,
        exportable=false,
        offline=false,
        server_config...
    )

A Page should be used for anything that displays multiple outputs, like Pluto/IJulia/Documenter.
It activates a special html mime show mode, which is more efficient in that scenario.

A Page creates a single entry point, to connect to the Julia process and load dependencies.
For Documenter, the page needs to be set to `exportable=true, offline=true`.
Exportable has the effect of inlining all data & js dependencies, so that everything can be loaded in a single HTML object.
`offline=true` will make the Page not even try to connect to a running Julia
process, which makes sense for the kind of static export we do in Documenter.

For convenience, one can also pass additional server configurations, which will directly
get put into `configure_server!(;server_config...)`.
Have a look at the docs for `configure_server!` to see the parameters.
"""
function Page(;
        session=nothing,
        exportable=false,
        offline=false,
        server_config...
    )
    configure_server!(;server_config...)
    if session === nothing
        serializer = UrlSerializer(inline_all=exportable)
        session = Session(url_serializer=serializer)
    end

    p = Page(
        session, Dict{String, Session}(),
        exportable,
        offline,
    )
    CURRENT_PAGE[] = p
    return p
end

function Base.close(page::Page)
    for (k, s) in page.child_sessions
        close(s)
    end
    empty!(page.child_sessions)
    close(page.session)
end

function Base.show(io::IO, ::MIME"text/html", page::Page)
    delete_session = Observable("")
    register_resource!(page.session, page.session.js_comm)

    init = init_connection(session)

    page_init_dom = DOM.div(track, init)
    node_html(io, page.session, page_init_dom)
    return
end

function assure_ready(page::Page)
    # Nothing to wait for when offline
    page.offline && return
    session = page.session
    filter!(page.child_sessions) do (id, session)
        never_opened = isnothing(session.connection[])
        if never_opened
            @warn("Removing unopened Session: $(id)")
            close(session)
        end
        return !never_opened
    end
    tstart = time()
    warned = false
    initialized = false
    while time() - tstart < 100
        children_loaded = all(isready, values(page.child_sessions))
        if isready(session) && children_loaded
            initialized = true
            break
        end
        if (time() - tstart) > 1 && !warned
            warned = true
            @warn("Waiting for page sessions to load.
                This can happen for the first cells to run, or is indicative of faulty state")
        end
        # yield / sleep to give websocket etc a chance to connect
        sleep(0.01)
    end
    if !initialized
        error("Could not initialize Page. Open an issue at JSServe.jl.")
    end
    send(session, fused_messages!(session))
end

function render_sub_session(parent_session, html_dom)
    session = Session(nothing)
    on_init = Observable(false)
    # Render the app and register all the resources with the session
    # Note, since we set the connection to nothing, nothing gets sent yet
    # This is important, since we can only sent the messages after the HTML has been rendered
    # since we must assume the messages / js contains references to HTML elements
    js_dom = jsrender(session, html_dom)

    new_deps = setdiff(session.dependencies, parent_session.dependencies)
    union!(parent_session.dependencies, new_deps)

    on(session, on_init) do is_init
        if !is_init
            error("The html didn't initialize correctly")
        end
        init_session(session)
    end

    init = js"""
    // register this session so it gets deleted when it gets removed from dom
    $(JSServeLib).register_sub_session($(session.id))
    update_obs($(on_init), true)
    """

    final_dom = DOM.span(
        js_dom,
        include_all_assets(parent_session, new_deps)...,
        jsrender(session, init),
        id=session.id,
    )

    obs_shared_with_parent = intersect(keys(session.observables), keys(parent_session.observables))
    # Those obs are managed by page session, so we don't need to have them in here!
    # This is important when we clean them up, since a child session shouldn't
    # delete any observable already managed by the parent session
    for obs in obs_shared_with_parent
        delete!(session.observables, obs)
    end

    # but in the end, all observables need to be registered
    # with the page session, since that's where javascript will sent all the events
    merge!(parent_session.observables, session.observables)

    # finally give page a connection! :)
    session.connection[] = parent_session.connection[]

    return final_dom
end


function show_in_page(page::Page, app::App)
    page_session = page.session
    is_offline = page.offline
    # The page session must be ready to display anything!
    # Since the page display is rendered async in the browser and we have no
    # idea when it's done on the Julia side, so we need to wait here!
    assure_ready(page)

    # Create a child session, to track the per app resources
    session = Session(nothing)
    # register with page session for proper clean up!
    page.child_sessions[session.id] = session

    on_init = Observable(false)
    # Render the app and register all the resources with the session
    # Note, since we set the connection to nothing, nothing gets sent yet
    # This is important, since we can only sent the messages after the HTML has been rendered
    # since we must assume the messages / js contains references to HTML elements
    html_dom = Base.invokelatest(app.handler, session, (; show="/show_inline"))
    js_dom = jsrender(session, html_dom)

    new_deps = setdiff(session.dependencies, page_session.dependencies)
    union!(page_session.dependencies, new_deps)

    exportable = page.exportable

    on(session, on_init) do is_init
        if !is_init
            error("The html didn't initialize correctly")
        end
        init_session(session)
    end

    # unhide DOM last, when everything is done ()
    evaljs(session, js"""
        const application_dom = document.getElementById($(session.id))
        application_dom.style.visibility = 'visible'
    """)

    init = if exportable
        # We take all messages and serialize them directly into the init js
        messages = fused_messages!(session)
        js"""(()=> {
            $(JSServeLib).register_sub_session($(session.id))
            const init_data_b64 = $(serialize_string(session, messages))
            $(JSServeLib).init_from_b64(init_data_b64)
            if (!$(is_offline)){
                update_obs($(on_init), true)
            }
        })()"""
    else
        js"""
            // register this session so it gets deleted when it gets removed from dom
            $(JSServeLib).register_sub_session($(session.id))
            update_obs($(on_init), true)
        """
    end

    final_dom = DOM.div(
        js_dom,
        include_all_assets(page_session, new_deps)...,
        jsrender(session, init),
        id=session.id,
        # we hide the dom, so the user can't interact before
        # all js connections are loaded
        style="visibility: hidden;"
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

    # finally give page a connection! :)
    session.connection[] = page_session.connection[]

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
    app_wrapped = App() do session::Session, request
        on_document_load(session, js"JSServe.resize_iframe_parent($(session.id))")
        html_dom = Base.invokelatest(app.handler, session, request)
        return html_dom
    end
    route!(server, session_route => app_wrapped)
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
function page_html(session::Session, html)
    proxy_url = JSSERVE_CONFIGURATION.external_url[]
    serializer = session.url_serializer
    rendered = jsrender(session, html)
    session_deps = include_asset.(session.dependencies, (serializer,))

    onload = jsrender(session, js"""
        window.addEventListener('load', (event) => {
            const proxy_url = $(proxy_url)
            const session_id = $(session.id)
            $(JSServeLib).setup_connection({proxy_url, session_id})
            $(JSServeLib).sent_done_loading()
        })
    """)

    html_body = DOM.html(
        DOM.head(
            DOM.meta(charset="UTF-8"),
            session_deps...
        ),
        DOM.body(
            DOM.div(rendered, id="application-dom", style="visibility: hidden;"),
            onload
        )
    )
    return sprint() do io
        println(io, "<!doctype html>")
        show(io, MIME"text/html"(), Hyperscript.Pretty(html_body))
    end
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
