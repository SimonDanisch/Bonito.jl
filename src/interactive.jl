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

function interactive_server(f, paths, modules=[]; url="127.0.0.1", port=8081, track_main_includes=true, all=false)
    server = Server(url, port)
    if isdefined(Main, :Revise)
        R = Main.Revise
        R.tracking_Main_includes[] = track_main_includes
        routes_channel = Channel{Routes}(1)
        R.entr(paths, modules; all=all) do
            routes = f()
            for (route, app) in routes.routes
                update_route!(server, (route, app))
            end
            put!(routes_channel, routes)
        end
        Base.timedwait(10) do
            istaskfailed(task) || isready(routes_channel)
        end
        if istaskfailed(task)
            fetch(task)
        end
        errormonitor(task)
        routes = take!(routes_channel)
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
