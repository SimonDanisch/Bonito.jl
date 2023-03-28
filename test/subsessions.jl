
@testset "subsession" begin
    global_obs = JSServe.Retain(Observable{Any}("hiii"))
    dom_obs1 = Observable{Any}(DOM.div("12345", js"$(global_obs).notify('hello')"))
    app = App() do s
        global session = s
        return DOM.div(dom_obs1)
    end
    display(edisplay, app)
    @test app.session[] == session
    @test length(session.children) == 1
    @test JSServe.wait_for(()-> global_obs.value[] == "hello") == :success
    obs_sub = last(first(session.children)) # the session used to render dom_obs1
    @test obs_sub.session_objects[global_obs.value.id] == nothing
    root = JSServe.root_session(session)
    @test root.session_objects[global_obs.value.id] == global_obs
    @test length(session.children) == 1

    dom_obs1[] = DOM.div("95384", js"""$(global_obs).notify('melo')""")

    @test JSServe.wait_for(() -> global_obs.value[] == "melo") == :success

    # Sessions should be closed!
    @test isempty(obs_sub.session_objects)
    @test obs_sub.status == JSServe.CLOSED
    @test !isopen(obs_sub)
    @test length(session.children) == 1 # there should be a new session though
    obs_sub = last(first(session.children)) # the session used to render dom_obs1
    @test obs_sub.session_objects[global_obs.value.id] == nothing
    @test haskey(session.parent.session_objects, global_obs.value.id)
end

@testset "subsession & freing" begin
    server = Server("0.0.0.0", 9433)
    session = JSServe.HTTPSession(server)
    sub1 = Session(session)
    sub2 = Session(session)
    subsub = Session(sub1)
    obs1 = Observable(1)
    obs2 = Observable(2)
    obs3 = Observable(3)
    obs4 = Observable(4)
    add_cached!(s, obs) = JSServe.add_cached!(() -> obs, s, Dict{String,Any}(), obs)
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

    server = session.asset_server.server

    for (route, s) in server.routes.table
        @test !(s isa HTTPAssetServer)
    end
end
