@testset "Observable + Session cleanup (parent-owned)" begin
    # When an Observable is interpolated DIRECTLY by the App's session (not
    # only by inner sub-sessions that `jsrender`'s `Observable` overload
    # spawns for nested observables), the App's session becomes the owner.
    # That ownership keeps the JS-side reference alive across `dom_obs1[] =
    # …` reassignments that close one rendering sub and open another.
    # The pattern below uses an `evaljs(s, js"$(global_obs);")` purely as a
    # registration mechanism — the JS expression itself is a no-op, but the
    # interpolation routes `global_obs` through `add_cached!` with the App
    # session as the calling session.
    global_obs = Observable{Any}("hiii")
    for i in 1:5
        dom_obs1 = Observable{Any}(DOM.div("12345", js"$(global_obs).notify('hello')"))
        app = App() do s
            # Register `global_obs` under the App session so it survives
            # inner sub re-renders. The JS body is a no-op.
            Bonito.evaljs(s, js"void $(global_obs);")
            return DOM.div(dom_obs1)
        end
        display(edisplay, app)
        session = app.session[]
        @test Bonito.wait_for(() -> global_obs[] == "hello") == :success
        root = Bonito.root_session(session)
        @test root.session_objects[global_obs.id].object === global_obs
        # The App session is the owner that keeps the obs alive across the
        # dom_obs1 re-render below.
        @test session.id in root.session_objects[global_obs.id].owners
        # A render sub for dom_obs1 also tracks the obs via the JSCode's
        # CacheKey reference (value `nothing` is the tracking marker).
        obs_sub = first(s for (_, s) in session.children
                          if haskey(s.session_objects, global_obs.id))
        @test isnothing(obs_sub.session_objects[global_obs.id])

        dom_obs1[] = DOM.div("95384", js"""$(global_obs).notify('melo')""")
        @test Bonito.wait_for(() -> global_obs[] == "melo") == :success

        # Old rendering sub should be closed; a new one renders the new value
        # and re-registers the tracking marker.
        @test obs_sub.status == Bonito.CLOSED
        @test !isopen(obs_sub)
        @test any(s -> haskey(s.session_objects, global_obs.id),
                  values(session.children))
    end
end
Bonito.set_cleanup_time!(0.0)
@testset "server cleanup" begin
    # Close the full display (window + handler/session). `close(::ElectronDisplay)`
    # tears down the Bonito handler/session first (deregistering assets and
    # websocket routes) and then the Electron window — so root sessions free
    # their owners and global_obs can finally be GC'd.
    server = edisplay.browserdisplay.server
    close(edisplay)
    success = Bonito.wait_for(() -> isempty(server.websocket_routes.table); timeout=6)
    for (r, handler) in server.websocket_routes.table
        @show handler.session
    end
    @test success == :success
    # browser display route & asset server
    @test Set(first.(server.routes.table)) == Set(["/browser-display", r"\Q/assets/\E(?:(?:(?:[\da-f]){40})(?:-.*))"])
    asset_server = server.routes.table[2][2]
    # Force GC + wait for the deferred Session-level @async close finalizer
    # (types.jl) to drain. ChildAssetServer no longer has its own finalizer;
    # Session's safety-net @async close handles the orphaned-Session case.
    GC.gc(true)
    GC.gc(true)
    Bonito.wait_for(() -> isempty(asset_server.files); timeout=5)
    @test isempty(asset_server.files)
end
Bonito.set_cleanup_time!(30/60/60)

# Re-Create edisplay for other tests
edisplay = Bonito.use_electron_display(; app=get_test_app(), options=Dict{String, Any}("show" => false, "focusOnWebView" => false), devtools=false)

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
        @test session.session_objects[obs.id].object === obs
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
    @test session.session_objects[obs4.id].object === obs4
    @test subsub.session_objects[obs4.id] == nothing
    @test length(sub1.session_objects) == 2
    @test length(sub2.session_objects) == 2

    close(sub2)

    for obs in [obs1, obs2, obs3]
        @test session.session_objects[obs.id].object === obs
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

    @test isempty(session.asset_server.parent.files)
    close(server)
end

@testset "sub imports don't leak onto root; assets stay available" begin
    # Subs re-emit their own imports into their own fragment; they must not be
    # copied onto the root (that leaked in #399), and the asset server must keep a
    # shared asset alive while any holder is open.
    server = Server("0.0.0.0", 9478)
    root = Bonito.HTTPSession(server)
    file = joinpath(mktempdir(), "leaktest.js"); write(file, "window.X = 1;")
    parent = root.asset_server.parent
    key = "/assets/" * Bonito.unique_file_key(Asset(file))
    refcount() = (e = get(parent.files, key, nothing); e === nothing ? 0 : Bonito.refcount(e))
    app = App(s -> DOM.div("x", Asset(file)))

    subA = Session(root); Bonito.session_dom(subA, app)
    subB = Session(root); Bonito.session_dom(subB, app)
    @test refcount() == 2                # each open sub holds its own ref
    @test isempty(root.imports)          # not copied onto the root
    close(subA)
    @test refcount() == 1                # still available for the sibling (no race)
    close(subB)
    @test refcount() == 0                # freed when the last holder closes
    @test isempty(root.imports)
    @test isempty(parent.files)
    close(server)
end

@testset "a released registration never leaves the path on a dead holder" begin
    # Same content key, several holders, DIFFERENT asset objects — identical
    # bytes, but a proxied `RemoteAsset` also carries the registering worker's
    # bridge driver, so which object is served decides which driver is fetched
    # from. Serving the newest keeps a restarted worker in front; releasing it
    # has to fall back to a survivor, or the path strands on a closed holder and
    # every later fetch times out while a live holder exists.
    server = Server("0.0.0.0", 0)
    parent = Bonito.HTTPAssetServer(Dict{String,Bonito.AssetEntry}(), server,
                                    ReentrantLock())
    file = joinpath(mktempdir(), "adopt.js"); write(file, "window.Y = 1;")
    key = "/assets/" * Bonito.unique_file_key(Asset(file))
    served() = Bonito.served_asset(parent.files[key])
    reg!(child, asset) = lock(parent.lock) do
        Bonito.register!(parent, child, asset)
    end

    childA, childB = Bonito.ChildAssetServer(parent), Bonito.ChildAssetServer(parent)
    assetA, assetB = Asset(file), Asset(file)
    reg!(childA, assetA)
    reg!(childB, assetB)
    @test Bonito.refcount(parent.files[key]) == 2
    @test served() === assetB             # newest holder serves

    # The NEWEST holder leaves while an older one is still serving a page.
    close(childB)
    @test Bonito.refcount(parent.files[key]) == 1
    @test served() === assetA             # falls back, never stays on childB

    # And the mirror: re-register, then drop the OLDER one.
    childC = Bonito.ChildAssetServer(parent)
    assetC = Asset(file)
    reg!(childC, assetC)
    close(childA)
    @test Bonito.refcount(parent.files[key]) == 1
    @test served() === assetC

    close(childC)
    @test isempty(parent.files)           # last registration gone → entry dropped
    close(server)
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
