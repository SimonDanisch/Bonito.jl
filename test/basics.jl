@testset "basic session rendering" begin
    session = Session()
    obs1 = Observable(1)
    TestLib = JSServe.Dependency(:Test, ["bla.js"])
    dom = DOM.div(test=obs1, onload=js"$(TestLib).lol()")
    jsrender(session, dom)
    @test haskey(session.observables, obs1.id)
    # Obs registered correctly
    @test session.observables[obs1.id][1] # is registered
    @test obs1.listeners[1][2] isa JSServe.JSUpdateObservable
    @test session.message_queue[1][:msg_type] == JSServe.RegisterObservable
    @test session.message_queue[1][:id] == obs1.id

    # Will deregisters correctly on session close
    @test session.deregister_callbacks[1].observable === obs1
    @test length(session.dependencies) == 1
    @test first(session.dependencies).local_path == joinpath(pwd(), "bla.js")

    # onjs callback to update attributes
    @test session.message_queue[2][:msg_type] == JSServe.OnjsCallback
    @test occursin("JSServe.update_node_attribute", string(session.message_queue[2][:payload]))
end

@testset "Page rendering & cleanup" begin
    io = IOBuffer()
    open_session = JSServe.Session(Base.RefValue{Union{Nothing, JSServe.WebSocket, IOBuffer}}(io))
    put!(open_session.js_fully_loaded, true)
    page = JSServe.Page(session=open_session)
    @test isopen(page.session)
    rslider = JSServe.RangeSlider(1:100; value=[10, 80])

    for obs_field in (:range, :value, :connect, :orientation, :tooltips, :ticks)
        obs = getfield(rslider, obs_field)
        @test isempty(obs.listeners)
    end

    sliderapp = JSServe.App(rslider)
    html = JSServe.show_in_page(page, sliderapp)
    @test length(page.child_sessions) == 1
    c_session = first(page.child_sessions)[2]
    # ID of div correctly set to child session
    @test occursin("<div id=\"$(c_session.id)\"", html)

    @testset "assets" begin
        dependencies = getfield.(c_session.dependencies, :local_path)
        @test length(dependencies) == 2
        @test JSServe.noUiSlider.assets[1].local_path in dependencies
        @test JSServe.noUiSlider.assets[2].local_path in dependencies
    end

    for obs_field in (:range, :value, :connect, :orientation, :tooltips, :ticks)
        obs = getfield(rslider, obs_field)
        @test length(obs.listeners) == 1
    end

    @testset "closing" begin
        c_session.connection[] = nothing
        close(c_session)
        delete!(page.child_sessions, c_session.id)
        # All listeners should get disconnected!
        for obs_field in (:range, :value, :connect, :orientation, :tooltips, :ticks)
            obs = getfield(rslider, obs_field)
            @test isempty(obs.listeners)
        end
        # all obs need to get removed
        @test isempty(open_session.observables)
    end

    @testset "dependency second include" begin
        html2 = JSServe.show_in_page(page, sliderapp)
        # Test that dependencies only get loaded one time!
        @test !occursin("-nouislider.min.js", html2)
        @test !occursin("nouislider.min.css", html2)

        id, session = first(page.child_sessions)
        session.connection[] = nothing
        close(session)
        delete!(page.child_sessions, id)
    end

    @test isempty(page.session.observables)
    @test isempty(page.session.unique_object_cache)
    # Wrap in func, to make sure we dont capture any reference globally
    function gc_avoid_func()
        dublicate = rand(1000, 1000)
        dub_ref = JSServe.pointer_identity(dublicate)
        dom = JSServe.App() do session
            JSServe.evaljs(session, js"$(dublicate); $(dublicate)")
            JSServe.evaljs(session, js"$(dublicate); $(dublicate)")
            return JSServe.DOM.div()
        end
        html = JSServe.show_in_page(page, dom)
        id, session = first(page.child_sessions)
        # There should only be one obs registered, which is the init obs
        (id, (reg, init_obs)) = first(open_session.observables)

        @test init_obs[] isa Bool
        @test !init_obs[] # shouldn't be initialized yet
        @test isopen(session)
        session.connection[] = nothing
        @test !isopen(session)
        # there should be 3 messages in here
        # 2 for evaljs, one for registering the int_obs
        @test length(session.message_queue) == 4
        @test isempty(open_session.unique_object_cache)
        init_obs[] = true
        @test !isempty(session.message_queue)
        # There should only be two messages now, 1 fused message that sends all messages in one go
        # and one to update obs
        @test length(session.message_queue) == 2
        @test session.message_queue[1][:msg_type] == JSServe.FusedMessage

        session.connection[] = open_session.connection[]
        messages = copy(session.message_queue)
        empty!(session.message_queue)
        for msg in messages
            JSServe.send(session, msg)
        end
        @test !isempty(session.unique_object_cache)
        @test haskey(session.unique_object_cache, dub_ref)
        obj = session.unique_object_cache[dub_ref]
        @test obj.value === dublicate
        session.connection[] = nothing
        close(session)
        dublicate = nothing
        obj = nothing
        @test isempty(session.message_queue)
        @test isempty(session.deregister_callbacks)

        return dub_ref
    end

    dub_ref = gc_avoid_func()
    # Ok, somehow GC is bitchy - but after some time it works
    function test_ref()
        tstart = time()
        while time() - tstart < 30
            id, obj = first(open_session.unique_object_cache)
            isnothing(obj.value) && return true
            yield()
            GC.gc(true)
        end
        return false
    end

    # @test test_ref()
    # # cache get cleaned up on any serialization event.
    # # the object, doesn't really matter
    # obj = Dict("helo" => 22)
    # binary = JSServe.serialize_binary(open_session, obj)
    # data_unpacked = JSServe.MsgPack.unpack(transcode(JSServe.GzipDecompressor, binary))
    # @show data_unpacked
    # @test isempty(data_unpacked["update_cache"]["to_register"])
    # @test data_unpacked["update_cache"]["to_remove"][1] == dub_ref
end
