Base.showable(::Union{MIME"text/html", MIME"application/prs.juno.plotpane+html"}, ::App) = true

const CURRENT_SESSION = Ref{Union{Nothing, Session}}(nothing)

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

"""
    page_html(session::Session, html_body)

Embeds the html_body in a standalone html document!
"""
function page_html(io::IO, session::Session, app_node::Union{Node, App})
    dom = session_dom(session, app_node; html_document=true)
    println(io, "<!doctype html>")
    # use Hyperscript directly to avoid the additional jsserve attributes
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



# Poor mans Require.jl for Electron
const ELECTRON_PKG_ID = Base.PkgId(Base.UUID("a1bb12fb-d4d1-54b4-b10a-ee7951ef7ad3"), "Electron")
function Electron()
    if haskey(Base.loaded_modules, ELECTRON_PKG_ID)
        return Base.loaded_modules[ELECTRON_PKG_ID]
    else
        error("Please Load Electron, if you want to use it!")
    end
end

struct ElectronDisplay{EWindow} <: Base.Multimedia.AbstractDisplay
    window::EWindow # a type parameter here so, that we dont need to depend on Electron Directly!
end

function ElectronDisplay()
    w = Electron().Window()
    Electron().toggle_devtools(w)
    return ElectronDisplay(w)
end

Base.displayable(d::ElectronDisplay, ::MIME{Symbol("text/html")}) = true

function Base.display(ed::ElectronDisplay, app::App)
    d = JSServe.HTTPServer.BrowserDisplay()
    session_url = "/browser-display"
    s = JSServe.HTTPServer.server(d)
    old_app = JSServe.route!(s, Pair{Any,Any}(session_url, app))
    url = JSServe.online_url(s, "/browser-display")
    return Electron().load(ed.window, JSServe.URI(url))
end

function use_electron_display()
    disp = ElectronDisplay()
    Base.Multimedia.pushdisplay(disp)
    return disp
end
