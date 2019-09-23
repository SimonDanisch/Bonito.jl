
const global_application = Ref{Application}()

const plotpane_pages = Dict{String, Any}()

function atom_dom_handler(request::Request)
    sessionid = request_to_sessionid(request, throw = false)
    sessionid === nothing && return nothing
    if haskey(plotpane_pages, sessionid)
        return sessionid, plotpane_pages[sessionid]
    else
        @warn "Cannot find session! Target: $(sessionid). Request: $(request)"
    end
end


struct DisplayInline
    dom
    session::Session
    sessionid::String
end

DisplayInline(dom) = DisplayInline(dom, Session(Ref{WebSocket}()), string(uuid4()))
DisplayInline(dom, session::Session) = DisplayInline(dom, session, string(uuid4()))


"""
    with_session(f)::DisplayInline

calls f with the session, that will become active when displaying the result
of with_session. f is expected to return a valid DOM.
"""
function with_session(f)
    session = Session(Ref{WebSocket}())
    DisplayInline(f(session), session)
end

const WebMimes = (
    MIME"text/html",
    MIME"application/prs.juno.plotpane+html",
    # MIME"application/vnd.webio.application+html"
)

function get_global_app()
    if !isassigned(global_application) || istaskdone(global_application[].server_task[])
        global_application[] = Application(
            atom_dom_handler,
            get(ENV, "WEBIO_SERVER_HOST_URL", "127.0.0.1"),
            parse(Int, get(ENV, "WEBIO_HTTP_PORT", "8081")),
            verbose = get(ENV, "JSCALL_VERBOSITY_LEVEL", "false") == "true"
        )
    end
    global_application[]
end

for M in WebMimes
    @eval function Base.show(io::IO, m::$M, dom::DisplayInline)
        application = get_global_app()
        sessionid = dom.sessionid
        session = dom.session
        application.sessions[sessionid] = session
        plotpane_pages[sessionid] = dom.dom
        println(io, "<iframe src=$(repr(server_proxy_url[] * "/" * sessionid)) frameborder=\"0\" width = '100%' height = '100%'>")
        println(io, "</iframe>")
    end
end
# function Base.show(io::IO, m::MIME"text/html", dom::Hyperscript.Node)
#     inline_display = with_session() do session
#         dom
#     end
#     show(io, m, inline_display)
# end
# function Base.show(io::IO, m::MIME"text/html", dom::Markdown.MD)
#     inline_display = with_session() do session
#         dom
#     end
#     show(io, m, inline_display)
# end
function Base.show(io::IO, m::MIME"application/vnd.webio.application+html", dom::DisplayInline)
    application = get_global_app()
    application.sessions[dom.sessionid] = dom.session
    dom2html(io, dom.session, dom.sessionid, dom.dom)
end
