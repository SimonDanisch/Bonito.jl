@testset "basic session rendering" begin
    # Use no connection, since otherwise the session will be added to
    # The global running HTTP server
    session = OfflineSession()
    obs1 = Observable(1)
    TestLib = Bonito.BonitoLib
    dom = App(DOM.div(test=obs1, onload=js"$(TestLib).lol()"))
    sdom = Bonito.session_dom(session, dom; init=false) # Init false to not inline messages
    msg = Bonito.fused_messages!(session)
    data = Bonito.SerializedMessage(session, msg)
    decoded = msg[:payload][1]
    mapped = obs1.listeners[1][2].result # we map(render, obs1) when rendering attributes, so only that will be in the session
    @test haskey(session.session_objects, mapped.id)
    # Obs registered correctly
    @test mapped.listeners[1][2] isa Bonito.JSUpdateObservable
    session_cache = decoded.cache
    @test session_cache isa Bonito.SessionCache
    @test haskey(session_cache.objects, mapped.id)
    @test haskey(session.session_objects, mapped.id)

    # Will deregisters correctly on session close
    @test length(session.deregister_callbacks) == 1
    @test session.deregister_callbacks[1].observable === obs1
    @test occursin("Bonito.update_node_attribute", string(decoded.data["payload"]))
    close(session)
    @test isempty(obs1.listeners)
    @test isempty(mapped.listeners)
end

struct DebugConnection <: Bonito.FrontendConnection
    io::IOBuffer
end

DebugConnection() = DebugConnection(IOBuffer())
Base.write(connection::DebugConnection, bytes::AbstractVector{UInt8}) = write(connection.io, bytes)
Base.isopen(connection::DebugConnection) = isopen(connection.io)
Base.close(connection::DebugConnection) = close(connection.io)
setup_connection(session::Session{DebugConnection}) = nothing

@testset "Session & Subsession rendering & cleanup" begin
    connection = DebugConnection()
    open_session = Bonito.Session(connection; asset_server=Bonito.NoServer())
    put!(open_session.connection_ready, true)
    @test isopen(open_session)
    Bonito.CURRENT_SESSION[] = open_session

    rslider = Bonito.RangeSlider(1:100; value=[10, 80])

    for obs_field in (:range, :value, :connect, :orientation, :tooltips, :ticks)
        obs = getfield(rslider, obs_field)
        @test isempty(obs.listeners)
    end

    sliderapp = Bonito.App(rslider);
    html = sprint() do io
        sub = Bonito.show(io, MIME"text/html"(), sliderapp)
        msg = Bonito.fused_messages!(sub)
        Bonito.serialize_binary(sub, msg)
    end

    @test length(open_session.children) == 1
    c_session = first(open_session.children)[2]
    # ID of div correctly set to child session
    @test occursin("id=\"$(c_session.id)\"", html)

    @testset "assets" begin
        @test length(c_session.session_objects) == 2
    end

    @testset "observable $(obs_field)" for obs_field in (:range, :value, :connect, :orientation, :tooltips, :ticks)
        obs = getfield(rslider, obs_field)
        @test length(obs.listeners) == 1
        if obs_field == :value
            @test haskey(open_session.session_objects, obs.id)
            @test obs.listeners[1][2] isa Bonito.JSUpdateObservable
        end
    end

    @testset "closing" begin
        close(c_session)
        # All listeners should get disconnected!
        for obs_field in (:range, :value, :connect, :orientation, :tooltips, :ticks)
            obs = getfield(rslider, obs_field)
            @test isempty(obs.listeners)
        end
        # all obs need to get removed
        @test isempty(c_session.session_objects)
        @test !haskey(open_session.children, c_session.id)
    end

    @testset "dependency second include" begin
        html2 = sprint() do io
            sub = Bonito.show(io, MIME"text/html"(), sliderapp)
            msg = Bonito.fused_messages!(sub)
            Bonito.serialize_binary(sub, msg)
        end
        # Test that dependencies only get loaded one time!
        @test !occursin("-nouislider.min.js", html2)
        @test !occursin("nouislider.min.css", html2)

        id, session = first(open_session.children)
        close(session)
        @test !haskey(open_session.children, session.id)
    end
end

function test_dangling_app()
    parent = OfflineSession()
    sub = Session(parent)
    init_dom = Bonito.session_dom(parent, App(nothing))
    app = App() do s
        obs = Observable(1)
        return evaljs(s, js"$(obs)")
    end
    sub_dom = Bonito.session_dom(sub, app)
    GC.gc(true)
    # If finalizer get triggered closing the session, there will be
    pso = parent.session_objects
    sso = sub.session_objects
    return !isempty(pso) && !isempty(sso) && all(v -> haskey(pso, v), collect(keys(sso)))
end

@testset "don't gc sessions for dangling apps" begin
    @test test_dangling_app()
    @test test_dangling_app()
end

@testset "observable update" begin
    obs1 = Observable(1)
    obs2 = Observable(2)
    obs3 = Observable(3)
    obs4 = Observable{Any}(4)

    function observable_update_app(s, r)
        evaljs(s, js"""
        $obs1.notify(0, true);
        $obs2.notify($obs1.value);
        $obs3.notify(12);
        $obs4.notify(null);
        """)
        return DOM.div()
    end

    testsession(observable_update_app; port=8555) do app
        @test obs1[] == 1
        @test obs2[] == 0
        @test obs3[] == 12
        @test obs4[] === nothing
    end
end

# @testset "" begin
#     obs2 = Observable("hey")
#     obs[] = App() do s
#         global sub = s
#         DOM.div("hehe", js"$(obs2).on(x=> console.log(x))")
#     end;

#     @test session.children[sub.id] === sub
#     @test sub.session_objects[obs2.id] == nothing
#     @test haskey(session.session_objects, obs2.id)
#     @test haskey(session.observables, obs2.id)
#     Bonito.evaljs_value(session, js"""(()=>{
#         return Bonito.Sessions.GLOBAL_OBJECT_CACHE[$(obs2.id)][1]
#     })()""")

#     obs[] = App(()-> DOM.div("hoehoe", js"console.log('please delete old session?')"));
#     @test !haskey(session.children, sub.id)
#     @test !haskey(session.session_objects, obs2.id)
#     @test !haskey(session.observables, obs2.id)

#     @test Bonito.evaljs_value(session, js"""(()=>{
#         const a = $(obs2.id) in Bonito.Sessions.GLOBAL_OBJECT_CACHE
#         const b = $(sub.id) in Bonito.Sessions.SESSIONS
#         return !a && !b
#     })()""")

#     session.observables

#     Bonito.evaljs_value(session, js"""(()=>{
#         return Bonito.Sessions.GLOBAL_OBJECT_CACHE.length
#     })()""")

#     color = Observable("color: red;")
#     text = Observable("hehe")
#     app = App() do
#         DOM.div(text; style=color)
#     end;

#     parent = Session()
#     Bonito.session_dom(parent, app)

#     @test haskey(parent.observables, color.id)
#     @test haskey(parent.observables, text.listeners[1][2].html.id)

#     session = Session(parent)

#     new_obs = Observable([1,23,])
#     app2 = App() do
#         DOM.div(js"$new_obs"; style=color)
#     end;
#     dom = Bonito.session_dom(session, app2)

#     msg = Bonito.fused_messages!(session)
#     ser_msg = Bonito.serialize_cached(session, msg)

#     @test Bonito.root_session(session) == parent
#     @test Bonito.root_session(session) !== session

#     # Session shouldn't own, color
#     @test !haskey(session.session_objects, color.id)
#     @test session.session_objects[new_obs.id] == nothing
#     @test haskey(parent.session_objects, new_obs.id)
#     close(session)

#     @test isempty(session.session_objects)
#     @test !isopen(session)
#     # New obs the session brought in should stay:
#     @test !haskey(parent.session_objects, new_obs.id)
#     @test haskey(parent.session_objects, color.id)

# end
