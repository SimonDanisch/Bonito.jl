Base.showable(::Union{MIME"text/html", MIME"application/prs.juno.plotpane+html"}, ::App) = true

const CURRENT_SESSION = Ref{Union{Nothing,Session}}(nothing)

"""
    Page(;
        offline=false, exportable=true,
        connection::Union{Nothing, FrontendConnection}=nothing,
        server_config...
    )

A Page can be used for resetting the JSServe state in a multi page display outputs, like it's the case for Pluto/IJulia/Documenter.
For Documenter, the page needs to be set to `exportable=true, offline=true`, but doesn't need to, since Page defaults to the most common parameters for known Packages.
Exportable has the effect of inlining all data & js dependencies, so that everything can be loaded in a single HTML object.
`offline=true` will make the Page not even try to connect to a running Julia
process, which makes sense for the kind of static export we do in Documenter.
For convenience, one can also pass additional server configurations, which will directly
get put into `configure_server!(;server_config...)`.
Have a look at the docs for `configure_server!` to see the parameters.
"""
function Page(;
        offline::Union{Bool,Nothing}=nothing,
        exportable::Union{Bool,Nothing}=nothing,
        connection::Union{Nothing, FrontendConnection}=nothing,
        current_page_dir = abspath(pwd()), # For documenter server
        server_config...)
    old_session = CURRENT_SESSION[]
    if !isempty(server_config)
        configure_server!(; server_config...)
    end
    if !isnothing(old_session)
        close(old_session)
    end
    CURRENT_SESSION[] = nothing
    if isnothing(offline) # do nothing
    elseif offline
        force_connection!(NoConnection())
    else
        force_connection!()
    end

    if isnothing(exportable) # do nothing
    elseif exportable
        force_asset_server!(NoServer())
    else
        force_asset_server!()
    end
    if !isnothing(connection)
        force_connection!(connection)
    end
    asset_server = default_asset_server()
    if asset_server isa DocumenterAssets
        asset_server.folder[] = current_page_dir
    end
    force_subsession!(true)
    return
end


function Base.show(io::IO, m::Union{MIME"text/html", MIME"application/prs.juno.plotpane+html"}, app::App)
    if !isnothing(CURRENT_SESSION[])
        # We render in a subsession
        parent = CURRENT_SESSION[]
        sub = Session(parent; title=app.title)
        dom = session_dom(sub, app)
    else
        session = Session(title=app.title)
        if _use_parent_session(session)
            CURRENT_SESSION[] = session
            empty_app = App(nothing)
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

function print_as_page(io::IO, dom::Node)
    println(io, "<!doctype html>")
    # use Hyperscript directly to avoid the additional JSServe attributes
    show(io, MIME"text/html"(), Hyperscript.Pretty(dom))
    return
end

"""
    page_html(session::Session, html_body)

Embeds the html_body in a standalone html document!
"""
function page_html(io::IO, session::Session, app_node::Union{Node, App})
    dom = session_dom(session, app_node; html_document=true)
    print_as_page(io dom)
    return
end

function Base.show(io::IOContext, m::MIME"application/vnd.JSServe.application+html", dom::App)
    show(io.io, MIME"text/html"(), dom)
end

function Base.show(io::IO, m::MIME"application/vnd.JSServe.application+html", app::App)
    show(IOContext(io), m, app)
end

function Base.show(io::IO, ::MIME"juliavscode/html", app::App)
    show(IOContext(io), MIME"text/html"(), app)
end
