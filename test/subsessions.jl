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
@testset "one Observable in a map(...) DOM and in a static handler" begin
    # The map's DOM renders as a subsession inside the page and ships the
    # Observable first. The static button's handler, in the page's own session,
    # used to get only a reference to it; the page reads its own session's
    # messages before the subsession's, so the reference resolved to null and
    # every click threw "Cannot read properties of null (reading 'notify')".
    action = Observable{Any}(nothing)
    rerender = Observable(1)
    app = App() do s
        rows = map(rerender) do n
            DOM.button("row"; id = "in-map-$(n)", onclick = js"e => $(action).notify('from the map')")
        end
        return DOM.div(rows, DOM.button("static"; id = "static", onclick = js"e => $(action).notify('from the page')"))
    end
    display(edisplay, app)
    click(id) = Bonito.evaljs(app.session[], js"document.getElementById($(id)).click()")
    click("static")
    @test Bonito.wait_for(() -> action[] == "from the page") == :success
    click("in-map-1")
    @test Bonito.wait_for(() -> action[] == "from the map") == :success
    # A new render of the map leaves both working.
    rerender[] = 2
    @test Bonito.wait_for(() -> Bonito.evaljs_value(app.session[], js"!!document.getElementById('in-map-2')")) == :success
    click("static")
    @test Bonito.wait_for(() -> action[] == "from the page") == :success
    click("in-map-2")
    @test Bonito.wait_for(() -> action[] == "from the map") == :success
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

@testset "a sub replaced before the browser loaded it keeps its assets until it has" begin
    # Rows that are sub-sessions of their own (a non-trivial Observable each),
    # with init messages, so the browser fetches every row's init payload. Three
    # renders back to back close the first generation on the server before the
    # browser has even received it; its payloads were gone by the time the
    # browser asked (404).
    row(tag, i) = map(x -> DOM.div("$tag row $x",
                                   js"window.__rows[$(tag)] = (window.__rows[$(tag)] || 0) + 1;"),
                      Observable(i))
    rows(tag) = DOM.div([row(tag, i) for i in 1:10]...)
    content = Observable{Any}(DOM.div("start"))
    app = App(s -> DOM.div(content))
    display(edisplay, app)
    sess = app.session[]
    root = Bonito.root_session(sess)
    # Payload fetches in flight, every one that fails, and every rejection
    # nobody handled.
    evaljs_value(sess, js"""(() => {
        window.__rows = {};
        window.__failed = [];
        window.__in_flight = 0;
        window.__fetch_binary = Bonito.fetch_binary;
        Bonito.fetch_binary = (url) => {
            window.__in_flight += 1;
            return window.__fetch_binary(url)
                .catch((e) => { window.__failed.push(String(e)); throw e; })
                .finally(() => { window.__in_flight -= 1; });
        };
        window.addEventListener('unhandledrejection', (e) => window.__failed.push(String(e.reason)));
        return true;
    })()""")
    # The root is shared with the tests before this one: only its own entries count.
    before = lock(() -> Set(keys(root.loading_in_browser)), root.deletion_lock)
    for k in 1:3
        content[] = rows("gen$k")
    end
    # The browser is done once the last generation ran (the earlier ones were
    # inserted, and so fetched, before it) and no payload fetch is in flight.
    done = js"(window.__rows['gen3'] || 0) === 10 && window.__in_flight === 0"
    @test Bonito.wait_for(() -> evaljs_value(sess, done)) == :success
    @test evaljs_value(sess, js"window.__failed") == []
    # Every sub displayed here was reported, so nothing waits on the browser.
    @test Bonito.wait_for(() -> lock(() -> issubset(keys(root.loading_in_browser), before),
                                     root.deletion_lock)) == :success
    evaljs_value(sess, js"(() => { Bonito.fetch_binary = window.__fetch_binary; return true; })()")
end

@testset "a payload the server turned away is fetched again when the app says so" begin
    # A login that ended turns the payload request away (here: 401). The app
    # decides when to ask again (`on_refused`, once the login is back); the
    # sub then loads as if nothing happened.
    content = Observable{Any}(DOM.div("start"))
    app = App(s -> DOM.div(content))
    display(edisplay, app)
    sess = app.session[]
    evaljs_value(sess, js"""(() => {
        window.__refused = [];
        window.__fetch = window.fetch;
        let turned_away = false;
        window.fetch = (url, opts) => {
            if (!turned_away && String(url).endsWith('.bin')) {
                turned_away = true;
                return Promise.resolve(new Response(null, {status: 401}));
            }
            return window.__fetch(url, opts);
        };
        Bonito.on_refused((url) => new Promise((resolve) => window.__refused.push(resolve)));
        return true;
    })()""")
    content[] = DOM.div(map(x -> DOM.div("row $x", js"window.__row_loaded = true;"), Observable(1)))
    # Asked straight through Electron: what Bonito sends the page meanwhile
    # waits behind the turned-away payload, so messages arrive in order.
    page(code) = run(edisplay.window, code)
    @test Bonito.wait_for(() -> page("window.__refused.length === 1")) == :success
    @test page("window.__row_loaded === undefined")
    page("window.__refused[0](); true")
    @test Bonito.wait_for(() -> page("window.__row_loaded === true")) == :success
    @test page("window.__refused.length") == 1
    page("window.fetch = window.__fetch; Bonito.on_refused(null); true")
end

@testset "a closed sub's assets wait for the browser's report" begin
    server = Server("127.0.0.1", 0)
    root = Bonito.HTTPSession(server)
    # `root` has no browser, so the reports are sent by hand.
    report(sub; exception = "nothing") = Bonito.process_message(root, Dict{String,Any}(
        "msg_type" => Bonito.JSDoneLoading, "session" => sub.id,
        "exception" => exception, "message" => "", "stacktrace" => "nothing"))
    displayed() = let displayed_sub = first(Bonito.render_subsession(root, DOM.div(js"1"); init = true))
        Bonito.mark_displayed!(displayed_sub)
        displayed_sub
    end

    # Closed before the browser reported: its init payload stays servable...
    sub = displayed()
    @test !isempty(sub.asset_server.files)
    close(sub)
    @test !isempty(sub.asset_server.files)
    # ...until the report, which failed: the payload was gone. That is no error
    # of the page.
    report(sub; exception = "Error: gone")
    @test isempty(sub.asset_server.files)
    @test isempty(root.loading_in_browser)
    @test root.init_error[] === nothing

    # Reported first, closed later: the close takes its assets.
    sub = displayed()
    report(sub)
    @test !isempty(sub.asset_server.files)
    close(sub)
    @test isempty(sub.asset_server.files)

    # A sub that is never reported goes once it is older than the grace period.
    sub = displayed()
    close(sub)
    lock(() -> Bonito.expect_browser_load!(root, displayed(); grace = 0.0), root.deletion_lock)
    @test isempty(sub.asset_server.files)

    # A live sub's failure is still the page's error.
    silence_logs(() -> report(displayed(); exception = "Error: real"))
    @test root.init_error[] isa Bonito.JSException
    close(root)
    close(server)
end

@testset "a subsession whose DOM leaves the document before it starts" begin
    # Content can be out of the document when its session starts: a virtual
    # list mounts a row and evicts it before the session's payload arrived, a
    # pane is hidden by detaching it. Node references resolved in the document
    # only, so the start-up code found null and the `onclick` was never attached
    # ("Bonito: skip onclick"): the row came back with a dead button.
    clicked = Observable(false)
    found = Observable{Any}(nothing)
    app = App(() -> DOM.div(DOM.div(; id = "late-mount")))
    display(edisplay, app)
    session = app.session[]
    button = DOM.button("go"; id = "late-button", onclick = js"e => $(clicked).notify(true)")
    content = DOM.div(button, js"$(found).notify($(button) !== null)")
    Bonito.dom_in_js(session, content, js"""(elem) => {
        const mount = document.getElementById('late-mount');
        mount.appendChild(elem);   // its session starts here...
        elem.remove();             // ...and finishes while the content is detached
        window.__late_content = elem;
    }""")
    @test Bonito.wait_for(() -> found[] !== nothing) == :success
    @test found[] === true
    evaljs(session, js"""(() => {
        document.getElementById('late-mount').appendChild(window.__late_content);
        document.getElementById('late-button').click();
    })()""")
    @test Bonito.wait_for(() -> clicked[]) == :success
end

# The page's object cache and Julia's owner sets must agree on what the page
# holds when it reads a bare reference (`TrackingOnly`). Both tests park part
# of the page out of the document, as a hidden pane or a virtual list does: the
# subs rendered there load their payload only once they are back.
function parked_page(outer1, outer2)
    app = App(() -> DOM.div(DOM.div(outer1; id = "parked-holder"), outer2; id = "parked-page"))
    display(edisplay, app)
    return app
end
park!(session) = evaljs(session, js"window.__parked = document.getElementById('parked-holder'); window.__parked.remove();")
unpark!(session) = evaljs(session, js"document.getElementById('parked-page').prepend(window.__parked);")
# What the page's copy of `obs` is when `code` runs, reported back to `seen`.
report_value(seen, obs) = js"$(seen).notify($(obs) ? $(obs).value : 'null')"

@testset "a reference to an object whose only copy waits in a parked payload" begin
    # The parked sub ships the Observable first. A sibling then got a bare
    # reference and read null ("TrackingOnly: Key 63483 not found in
    # GLOBAL_OBJECT_CACHE", then "Key 63483 not found! undefined").
    shared = Observable("shared")
    seen_parked, seen_sibling = Observable{Any}(nothing), Observable{Any}(nothing)
    outer1, outer2 = Observable{Any}(DOM.div("a")), Observable{Any}(DOM.div("b"))
    app = parked_page(outer1, outer2)
    session = app.session[]
    park!(session)
    outer1[] = DOM.div(Observable{Any}(DOM.div("parked", report_value(seen_parked, shared))))
    outer2[] = DOM.div("sibling", report_value(seen_sibling, shared))
    @test Bonito.wait_for(() -> seen_sibling[] !== nothing) == :success
    @test seen_sibling[] == "shared"
    unpark!(session)
    @test Bonito.wait_for(() -> seen_parked[] !== nothing) == :success
    @test seen_parked[] == "shared"
end

@testset "a parked bare reference outlives the sub whose copy it relies on" begin
    # A visible sub holds the Observable, so the parked one gets only a
    # reference. The visible sub is re-rendered away before the parked one is
    # read: the page freed the object, since no session it knew tracked it.
    shared = Observable("shared")
    seen_visible, seen_parked = Observable{Any}(nothing), Observable{Any}(nothing)
    outer1 = Observable{Any}(DOM.div("a"))
    outer2 = Observable{Any}(DOM.div("visible", report_value(seen_visible, shared)))
    app = parked_page(outer1, outer2)
    session = app.session[]
    root = Bonito.root_session(session)
    entry() = lock(() -> get(root.session_objects, shared.id, nothing), root.deletion_lock)
    @test Bonito.wait_for(() -> seen_visible[] == "shared") == :success
    @test Bonito.wait_for(() -> !isempty(entry().on_page)) == :success
    park!(session)
    outer1[] = DOM.div(Observable{Any}(DOM.div("parked", report_value(seen_parked, shared))))
    outer2[] = DOM.div("gone")
    outer2[] = DOM.div("gone again")
    # Only the parked sub owns it now, and the page was told to free the rest.
    @test Bonito.wait_for(() -> length(entry().owners) == 1 && isempty(entry().on_page)) == :success
    unpark!(session)
    @test Bonito.wait_for(() -> seen_parked[] !== nothing) == :success
    @test seen_parked[] == "shared"
end

@testset "an object the page holds is sent as a reference" begin
    # The fixes above ship a copy whenever the page might not hold one; once a
    # connected session's copy is read, new owners still get only the key.
    shared = Observable("shared")
    seen = Observable{Any}(nothing)
    app = App(() -> DOM.div("page", report_value(seen, shared)))
    display(edisplay, app)
    session = app.session[]
    root = Bonito.root_session(session)
    @test Bonito.wait_for(() -> seen[] == "shared") == :success
    @test Bonito.wait_for(() -> lock(() -> !isempty(root.session_objects[shared.id].on_page), root.deletion_lock)) == :success
    sub = Bonito.Session(session)
    sent = Dict{String, Any}()
    Bonito.add_cached!(() -> error("shipped a copy"), sub, sent, shared)
    @test sent[shared.id] == Bonito.TrackingOnly(shared.id)
    close(sub)
end

# An UpdateSession whose target is out of the document when it arrives: a
# virtual list evicted the row, a pane is detached while hidden. The target is
# built from a message, as a chat's tool body is, so Bonito created it.
function detached_target_page()
    app = App(() -> DOM.div(DOM.div(; id = "target-holder"); id = "target-page"))
    display(edisplay, app)
    session = app.session[]
    target = DOM.div("placeholder"; id = "update-target")
    Bonito.dom_in_js(session, target, js"(elem) => document.getElementById('target-holder').appendChild(elem)")
    Bonito.wait_for(() -> Bonito.evaljs_value(session, js"!!document.getElementById('update-target')"))
    evaljs(session, js"window.__target_holder = document.getElementById('target-holder'); window.__target_holder.remove();")
    return session, Bonito.uuid(session, target)
end
unpark_target!(session) = evaljs(session, js"document.getElementById('target-page').append(window.__target_holder);")
browser_knows(session, sub) = Bonito.evaljs_value(session, js"$(sub.id) in Bonito.Sessions.SESSIONS")

@testset "an update waits until its target is back in the document" begin
    # Applied into the detached target, code that finds its nodes in the
    # document only, as every Bonito before `lookup_node` generates it (an eval
    # worker on an older Bonito), found nothing: "Bonito: skip onclick", and the
    # button stayed dead once the target was back.
    found, clicked = Observable{Any}(nothing), Observable(false)
    session, target = detached_target_page()
    content = DOM.div(DOM.button("go"; id = "old-style-button"), js"""(() => {
        const e = document.getElementById('old-style-button');
        if (e) { e.onclick = () => $(clicked).notify(true); }
        $(found).notify(e !== null);
    })()""")
    sub = Bonito.update_session_dom!(session, target, content; replace = false)
    @test Bonito.wait_for(() -> browser_knows(session, sub)) == :success
    sleep(0.5)
    @test found[] === nothing
    unpark_target!(session)
    @test Bonito.wait_for(() -> found[] !== nothing) == :success
    @test found[] === true
    evaljs(session, js"document.getElementById('old-style-button').click()")
    @test Bonito.wait_for(() -> clicked[]) == :success
end

@testset "an update freed while it waits for its target never applies" begin
    # Its target was replaced, and Julia closed the update's session. Applied
    # once a node with that id is back, it would start a session the page
    # already freed. Its code marks the target in the page: Julia drops what a
    # closed session notifies, so an Observable would not tell.
    done = Observable(false)
    session, target = detached_target_page()
    sub = Bonito.update_session_dom!(session, target,
        DOM.div("freed", js"document.getElementById('update-target').dataset.freedRan = 'yes'";
                id = "freed-update"); replace = false)
    @test Bonito.wait_for(() -> browser_knows(session, sub)) == :success
    close(sub)
    @test Bonito.wait_for(() -> !browser_knows(session, sub)) == :success
    unpark_target!(session)
    @test Bonito.wait_for(() -> Bonito.evaljs_value(session, js"!!document.getElementById('update-target')")) == :success
    sleep(1.5)   # the freed update polls at most every second
    @test Bonito.evaljs_value(session, js"document.getElementById('update-target').dataset.freedRan ?? 'no'") == "no"
    @test !Bonito.evaljs_value(session, js"!!document.getElementById('freed-update')")
    # The target is back, and a live update on it applies.
    Bonito.update_session_dom!(session, target, DOM.div("live", js"$(done).notify(true)"); replace = false)
    @test Bonito.wait_for(() -> done[]) == :success
end

# `on_free` teardowns run once, when their session is freed.
struct OnFreeProbe
    label::String
end
function Bonito.jsrender(session::Session, p::OnFreeProbe)
    return Bonito.jsrender(session, DOM.div(p.label,
        js"""Bonito.Sessions.on_free($(session.id), () => {
            window.__on_free = (window.__on_free || []).concat([$(p.label)]);
        })"""; class = "on-free-probe"))
end

@testset "on_free runs once its session is freed" begin
    # The display reuses its page: labels unique to this run.
    run = string(rand(UInt32); base = 16)
    label(x) = "$(run)-$(x)"
    content = Observable{Any}(OnFreeProbe(label("first")))
    app = App(() -> DOM.div(content; id = "on-free-host"))
    display(edisplay, app)
    session = app.session[]
    freed() = [replace(x, "$(run)-" => "") for x in Bonito.evaljs_value(session, js"window.__on_free || []") if startswith(x, run)]
    @test Bonito.wait_for(() -> Bonito.evaljs_value(session, js"!!document.querySelector('.on-free-probe')")) == :success
    @test freed() == []
    # A re-render closes the replaced sub one render later (double-buffered,
    # see `detach_subsession!`); the teardown runs when it is freed, once.
    content[] = OnFreeProbe(label("second"))
    content[] = OnFreeProbe(label("third"))
    @test Bonito.wait_for(() -> freed() == ["first"]) == :success
    content[] = OnFreeProbe(label("fourth"))
    @test Bonito.wait_for(() -> freed() == ["first", "second"]) == :success
    # Its DOM leaving the document: the browser closes the session itself.
    evaljs(session, js"document.getElementById('on-free-host').remove()")
    @test Bonito.wait_for(() -> "fourth" in freed()) == :success
    # Code that runs after its session is gone gets the teardown right away.
    @test Bonito.evaljs_value(session, js"""(() => {
        let ran = false;
        Bonito.Sessions.on_free("no-such-session", () => { ran = true; });
        return ran; })()""") == true
end
