@testset "basic session rendering" begin
    session = Session()
    obs1 = Observable(1)
    TestLib = JSServe.JSServeLib
    dom = App(DOM.div(test=obs1, onload=js"$(TestLib).lol()"))
    sdom = JSServe.session_dom(session, dom)
    msg = JSServe.fused_messages!(session)
    data = JSServe.serialize_cached(session, msg)
    @test haskey(session.session_objects, obs1.id)
    # Obs registered correctly
    @test obs1.listeners[1][2] isa JSServe.JSUpdateObservable
    @test haskey(data[:session_objects], obs1.id)

    # Will deregisters correctly on session close
    @test session.deregister_callbacks[1].observable === obs1
    @test occursin("JSServe.update_node_attribute", string(msg[:payload][1][:payload]))
end

struct DebugConnection <: JSServe.FrontendConnection
    io::IOBuffer
end

DebugConnection() = DebugConnection(IOBuffer())
Base.write(connection::DebugConnection, bytes) = write(connection.io, bytes)
Base.isopen(connection::DebugConnection) = isopen(connection.io)
Base.close(connection::DebugConnection) = close(connection.io)
function setup_connection(session::Session{DebugConnection})
    return nothing
end

@testset "Page rendering & cleanup" begin
    connection = DebugConnection()
    open_session = JSServe.Session(connection; asset_server=JSServe.NoServer())
    put!(open_session.connection_ready, true)
    @test isopen(open_session)
    JSServe.CURRENT_SESSION[] = open_session

    rslider = JSServe.RangeSlider(1:100; value=[10, 80])

    for obs_field in (:range, :value, :connect, :orientation, :tooltips, :ticks)
        obs = getfield(rslider, obs_field)
        @test isempty(obs.listeners)
    end

    sliderapp = JSServe.App(rslider);
    html = sprint() do io
        sub = JSServe.show(io, MIME"text/html"(), sliderapp)
        msg = JSServe.fused_messages!(sub)
        JSServe.serialize_binary(sub, msg)
    end

    @test length(open_session.children) == 1
    c_session = first(open_session.children)[2]
    # ID of div correctly set to child session
    @test occursin("<div id=\"$(c_session.id)\"", html)

    @testset "assets" begin
        @test length(c_session.session_objects) == 3
        @test haskey(c_session.session_objects, JSServe.object_identity(JSServe.noUiSlider))
        @test open_session.session_objects[JSServe.object_identity(JSServe.noUiSlider)] === JSServe.noUiSlider
    end

    for obs_field in (:range, :value, :connect, :orientation, :tooltips, :ticks)
        obs = getfield(rslider, obs_field)
        @test length(obs.listeners) == 1
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
            sub = JSServe.show(io, MIME"text/html"(), sliderapp)
            msg = JSServe.fused_messages!(sub)
            JSServe.serialize_binary(sub, msg)
        end
        # Test that dependencies only get loaded one time!
        @test !occursin("-nouislider.min.js", html2)
        @test !occursin("nouislider.min.css", html2)

        id, session = first(open_session.children)
        close(session)
        @test !haskey(open_session.children, session.id)
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
#     JSServe.evaljs_value(session, js"""(()=>{
#         return JSServe.Sessions.GLOBAL_OBJECT_CACHE[$(obs2.id)][1]
#     })()""")

#     obs[] = App(()-> DOM.div("hoehoe", js"console.log('please delete old session?')"));
#     @test !haskey(session.children, sub.id)
#     @test !haskey(session.session_objects, obs2.id)
#     @test !haskey(session.observables, obs2.id)

#     @test JSServe.evaljs_value(session, js"""(()=>{
#         const a = $(obs2.id) in JSServe.Sessions.GLOBAL_OBJECT_CACHE
#         const b = $(sub.id) in JSServe.Sessions.SESSIONS
#         return !a && !b
#     })()""")

#     session.observables

#     JSServe.evaljs_value(session, js"""(()=>{
#         return JSServe.Sessions.GLOBAL_OBJECT_CACHE.length
#     })()""")

#     color = Observable("color: red;")
#     text = Observable("hehe")
#     app = App() do
#         DOM.div(text; style=color)
#     end;

#     parent = Session()
#     JSServe.session_dom(parent, app)

#     @test haskey(parent.observables, color.id)
#     @test haskey(parent.observables, text.listeners[1][2].html.id)

#     session = Session(parent)

#     new_obs = Observable([1,23,])
#     app2 = App() do
#         DOM.div(js"$new_obs"; style=color)
#     end;
#     dom = JSServe.session_dom(session, app2)

#     msg = JSServe.fused_messages!(session)
#     ser_msg = JSServe.serialize_cached(session, msg)

#     @test JSServe.root_session(session) == parent
#     @test JSServe.root_session(session) !== session

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
