@testset "Retain + Observable + Session cleanup" begin
    global_obs = Bonito.Retain(Observable{Any}("hiii"))
    for i in 1:5
        dom_obs1 = Observable{Any}(DOM.div("12345", js"$(global_obs).notify('hello')"))
        app = App() do s
            return DOM.div(dom_obs1)
        end
        display(edisplay, app)
        app_id = app.session[].id
        obs_id = first(app.session[].children)[2].id
        session = app.session[]
        @test length(session.children) == 1
        @test Bonito.wait_for(()-> global_obs.value[] == "hello") == :success
        obs_sub = last(first(session.children)) # the session used to render dom_obs1
        @test isnothing(obs_sub.session_objects[global_obs.value.id])
        root = Bonito.root_session(session)
        @test root.session_objects[global_obs.value.id] == global_obs
        @test length(session.children) == 1

        dom_obs1[] = DOM.div("95384", js"""$(global_obs).notify('melo')""")

        @test Bonito.wait_for(() -> global_obs.value[] == "melo") == :success

        # Sessions should be closed!
        @test isempty(obs_sub.session_objects)
        @test obs_sub.status == Bonito.CLOSED
        @test !isopen(obs_sub)
        @test length(session.children) == 1 # there should be a new session though
        obs_sub = last(first(session.children)) # the session used to render dom_obs1
        @test isnothing(obs_sub.session_objects[global_obs.value.id])
        @test haskey(session.parent.session_objects, global_obs.value.id)
    end
    @testset "no residuals" begin
        app = App(nothing)
        display(edisplay, app)
        js_sessions = run(edisplay.window, "Bonito.Sessions.SESSIONS")
        js_objects = run(edisplay.window, "Bonito.Sessions.GLOBAL_OBJECT_CACHE")
        @test Set([app.session[].id, app.session[].parent.id]) == keys(js_sessions)
        @test keys(js_objects) == Set([global_obs.value.id]) # we used Retain for global_obs, so it should stay as long as root session is open
    end
end

@testset "server cleanup" begin
    # Close edisplay to remove Retain (gotta add a functionality to do this nonviolently)
    # But this is also a good chance to test server cleanup :)
    close(edisplay.window)
    server = edisplay.browserdisplay.server
    # It may take a while for close(edisplay.window) to remove the websocket route (by closing the socket)
    success = Bonito.wait_for(() -> isempty(server.websocket_routes.table); timeout=6)
    for (r, handler) in server.websocket_routes.table
        @show handler.session
    end
    @test success == :success
    # browser display route & asset server
    @test Set(first.(server.routes.table)) == Set(["/browser-display", r"\Q/assets/\E(?:(?:(?:[\da-f]){40})(?:-.*))"])
    asset_server = server.routes.table[2][2]
    @test isempty(asset_server.registered_files)
end

# Re-Create edisplay for other tests
edisplay = Bonito.use_electron_display(devtools=true)

@testset "subsession & freing" begin
    server = Server("0.0.0.0", 9433)
    session = Bonito.HTTPSession(server)
    sub1 = Session(session)
    sub2 = Session(session)
    subsub = Session(sub1)
    obs1 = Observable(1)
    obs2 = Observable(2)
    obs3 = Observable(3)
    obs4 = Observable(4)
    add_cached!(s, obs) = Bonito.add_cached!(() -> obs, s, Dict{String,Any}(), obs)
    add_cached!(sub1, obs1)
    add_cached!(sub1, obs3)
    add_cached!(sub2, obs2)
    add_cached!(sub2, obs3)

    add_cached!(subsub, obs1)
    add_cached!(subsub, obs2)
    add_cached!(subsub, obs3)

    for obs in [obs1, obs2, obs3]
        @test session.session_objects[obs.id] == obs
        @test subsub.session_objects[obs.id] == nothing
    end

    @test length(sub1.session_objects) == 2
    for obs in [obs1, obs3]
        @test sub1.session_objects[obs.id] == nothing
    end
    @test length(sub2.session_objects) == 2
    for obs in [obs2, obs3]
        @test sub2.session_objects[obs.id] == nothing
    end

    add_cached!(subsub, obs4)
    @test session.session_objects[obs4.id] == obs4
    @test subsub.session_objects[obs4.id] == nothing
    @test length(sub1.session_objects) == 2
    @test length(sub2.session_objects) == 2

    close(sub2)

    for obs in [obs1, obs2, obs3]
        @test session.session_objects[obs.id] == obs
        @test subsub.session_objects[obs.id] == nothing
    end

    @test length(sub1.session_objects) == 2
    for obs in [obs1, obs3]
        @test sub1.session_objects[obs.id] == nothing
    end

    @test isempty(sub2.session_objects)

    close(sub1)
    @test isempty(session.session_objects)
    @test isempty(sub1.session_objects)
    @test isempty(sub2.session_objects)
    @test isempty(subsub.session_objects)

    @test isempty(session.asset_server.parent.registered_files)

end

@testset "cleanup comm" begin
    app = App() do s
        return DOM.div()
    end
    display(edisplay, app)
    @test !isnothing(app.session[])
    @test isready(app.session[])
    Bonito.wait_for(() -> run(edisplay.window, "Object.keys(Bonito.Sessions.SESSIONS).length") == 2)
    @test run(edisplay.window, "Object.keys(Bonito.Sessions.SESSIONS).length") == 2
    root = Bonito.root_session(app.session[])
    @test root !== app.session[]
    @test run(edisplay.window, "Object.keys(Bonito.Sessions.GLOBAL_OBJECT_CACHE).length") == 0
    @test isempty(root.session_objects)
    close(app.session[])
    Bonito.wait_for(() -> run(edisplay.window, "Object.keys(Bonito.Sessions.SESSIONS).length") == 1)
    @test run(edisplay.window, "Object.keys(Bonito.Sessions.SESSIONS).length") == 1
end


@testset "Async evaljs_value" begin
    test_obs = Observable(0)
    app = App() do session
        obs = Observable(0)

        script = js"""
        window.obs_value = 0;
        for(let i = 0; i < 20; i++) {
            $(obs).notify(i);
        }
        """
        # on(obs_triggered_from_js)
        # with evaljs_value requires messages to be processed
        # async, since evaljs_value waits for a message from JS
        # while being triggered
        on(obs) do val
            @async begin
                jsval = evaljs_value(session, js"window.obs_value = $(val)"; timeout=1)
                test_obs[] = test_obs[] + 1
                return
            end
        end
        return DOM.div("Value: ", obs, script)
    end
    display(edisplay, app)
    Bonito.wait_for(() -> test_obs[] == 20)
    @test test_obs[] == 20
    @test run(edisplay.window, "window.obs_value") == 19
end
