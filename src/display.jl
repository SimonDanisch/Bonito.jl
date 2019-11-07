
const global_application = Ref{Application}()


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
    session = Session()
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
        application.sessions[sessionid] = Dict("base" => session)
        session_url = "/" * sessionid
        route!(application, session_url) do context
            # Serve the actual content
            return html(dom2html(session, sessionid, dom.dom))
        end
        # Display the route we just added in an iframe inline:
        println(io, "<iframe src=$(repr(url(session_url))) frameborder=\"0\" width = '100%' height = '100%'>")
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
