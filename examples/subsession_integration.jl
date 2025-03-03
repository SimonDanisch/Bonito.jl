using HTTP
using Bonito: App, Styles, Observable
using Bonito.DOM
using Random
using Colors
using Base.Threads: @spawn
using Dates: Dates


function html(app; kwargs...)
    io = IOBuffer()
    show_html(io, app; kwargs...)
    take!(io)
end

function main()
    # start a blocking server
    session_root_storage = Dict()
    rng = Random.default_rng()
    HTTP.listen() do http::HTTP.Stream
        HTTP.setstatus(http, 200)
        HTTP.startwrite(http)
        req_uri = HTTP.URI(http.message.target)
        if req_uri.path == "/fragment"
            params = HTTP.queryparams(req_uri)
            sid = params["sid"]
            session = session_root_storage[params["sid"]]
            color = rand(RGB{Float64})
            css = Styles(
                "background-color" => color,
            )
            app = App() do
                date_obs::Observable{String} = Observable("unset")
                @async begin
                    while true
                        date_obs[] = string(Dates.now())
                        sleep(1)
                    end
                end
                DOM.div(map(date -> "date: $(date); sid: $(sid)", date_obs), style=css)
            end
            app_html = html(app; parent=session)
            write(http, app_html)
        else
            root_app = App(_ -> DOM.div(""))
            app_html = html(root_app)
            session = root_app.session[]
            session_root_storage[session.id] = session
            write(http, "<html><body>")
            write(http, "<script src=\"https://unpkg.com/htmx.org@2.0.2\"></script>")
            write(http, "<h1>fragment insertion</h1>")
            write(http, "<button hx-get=\"/fragment?sid=$(session.id)\" hx-target=\"#results\">Click Me</button>")
            write(http, "<div id=\"results\">")
            write(http, app_html)
            write(http, "</div>")
            write(http, "</body></html>")
        end
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
