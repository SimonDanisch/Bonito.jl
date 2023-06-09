function update_route!(server, (route, app))
    old = route!(server, route => app)
    if old isa App && !isnothing(old.session[]) && isready(old.session[])
        try
            JSServe.evaljs(old.session[], js"window.location.reload()")
        catch e
            @warn "Failed to reload route $(route)" exception = e
        end
    end
end


const REVISE_LOOP = Base.RefValue(Base.RefValue(true))
const REVISE_SERVER = Base.RefValue{Union{Nothing, Server}}(nothing)

function interactive_server(f, paths, modules=[]; url="127.0.0.1", port=8081, all=true)
    if isnothing(REVISE_SERVER[])
        server = Server(url, port)
        REVISE_SERVER[] = server
    else
        server = REVISE_SERVER[]
    end
    if server.url != url && server.port != port
        close(server)
        server.url = url
        server.port = port
        HTTPServer.start(server)
    end
    if isdefined(Main, :Revise)
        Revise = Main.Revise
        # important to make `index = App(....)` work
        @eval Main __revise_mode__ = :evalassign
        function update_routes()
            routes = Base.invokelatest(f)
            for (route, app) in routes.routes
                update_route!(server, (route, app))
            end
            return routes
        end

        routes = update_routes()
        Revise.add_callback(update_routes, paths, modules; all=true, key="jsserver-revise")

        REVISE_LOOP[][] = false # stop old loop
        run = Base.RefValue(true) # get us a new loop variable
        REVISE_LOOP[] = run
        task = @async begin
            while run[]
                wait(Revise.revision_event)
                Revise.revise()
            end
            @info("quitting revise loop")
        end
        errormonitor(task)

        server_routes = Set(first.(server.routes.table))
        if !Base.all(r-> r in server_routes, keys(routes.routes))
            @warn "not all routes in server. Required routes: $(first(routes.routes)). Routes in server: $(server_routes)"
        end
        page = haskey(routes.routes, "/") ? "/" : first(routes.routes)[1]
        HTTPServer.openurl(online_url(server, page))
        return routes, task, server
    else
        error("Please load Revise into Main scope")
    end
end
