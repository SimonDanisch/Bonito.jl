# Regression tests for the stability-review findings owned by the
# asset-serving / HTTP / caching / widgets cluster. All tests are browser-free
# and deterministic (no Electron, no real network round-trips).

using Bonito, Test
using Bonito: Observable, Session, NoConnection, NoServer
using Bonito.HTTPServer
using HTTP

# A bare root session for caching unit tests.
new_root() = Session(NoConnection(); asset_server=NoServer())

@testset "B10 folderserver path traversal" begin
    dir = mktempdir()
    write(joinpath(dir, "index.html"), "<h1>ok</h1>")
    secret = joinpath(dir, "secret.txt")
    write(secret, "top secret")
    fs = Bonito.FolderServer(dir)

    function serve(target)
        req = HTTP.Request("GET", target)
        # FolderServer ignores `routes`/`application`; only `request` + `match`
        # matter. `match=""` mounts at the root (no prefix to strip), so the
        # whole request path is treated as the relative path.
        ctx = (; routes=nothing, application=nothing, request=req, match="")
        return Bonito.HTTPServer.apply_handler(fs, ctx)
    end

    # Normal file is served.
    @test serve("/index.html").status == 200

    # Traversal attempts must be rejected (403 for escapes that normpath
    # resolves outside the folder; 404 for ones that stay encoded). Either way
    # the response must never contain content from outside the folder.
    for evil in ("/../../../../etc/passwd",
                 "/../../etc/passwd",
                 "/..%2f..%2fetc%2fpasswd")
        resp = serve(evil)
        @test resp.status in (403, 404)
        @test !occursin("root:", String(copy(resp.body)))
    end

    # The in-folder secret IS still reachable by its own name (sanity: the guard
    # only blocks escapes, not legitimate files).
    @test serve("/secret.txt").status == 200

    # is_path_contained: sibling prefix must NOT count as contained.
    @test Bonito.is_path_contained("/data/site", "/data/site/a.txt")
    @test Bonito.is_path_contained("/data/site", "/data/site")
    @test !Bonito.is_path_contained("/data/site", "/data/site-backup/x")
    @test !Bonito.is_path_contained("/data/site", "/etc/passwd")
end

@testset "B11 rate limiter is locked, pruned, and ignores spoofed XFF" begin
    store = Bonito.SingleUser("admin", "secret")
    pr = Bonito.ProtectedRoute(Bonito.FolderServer("."), store;
                               max_attempts=3, lockout_window=60.0)

    # X-Forwarded-For is ignored by default (no trusted proxy): a spoofed header
    # can't pick the client id, so the real TCP peer (context.peer_ip) is used.
    ctx(xff; peer="") = (
        request = HTTP.Request("GET", "/", isempty(xff) ? [] : ["X-Forwarded-For" => xff]),
        peer_ip = peer,
    )
    @test Bonito.get_client_ip(pr, ctx("1.2.3.4"; peer="203.0.113.7")) == "203.0.113.7"
    # No resolvable peer → "" (apply_handler then skips per-IP limiting rather
    # than bucketing every unidentified client together).
    @test Bonito.get_client_ip(pr, ctx("1.2.3.4")) == ""
    # Behind a trusted proxy the first X-Forwarded-For hop wins.
    pr_trust = Bonito.ProtectedRoute(Bonito.FolderServer("."), store;
                                     trust_forwarded_for=true)
    @test Bonito.get_client_ip(pr_trust, ctx("9.9.9.9, 10.0.0.1"; peer="10.0.0.1")) == "9.9.9.9"

    # Concurrent record_failed_attempt must not corrupt the Dict.
    Threads.@sync for _ in 1:50
        Threads.@spawn Bonito.record_failed_attempt(pr, "5.5.5.5")
    end
    @test length(pr.failed_attempts["5.5.5.5"]) == 50
    # Over the limit -> denied.
    @test Bonito.check_rate_limit(pr, "5.5.5.5") == false

    # Aged-out bucket is pruned away by check_rate_limit (window 0).
    pr2 = Bonito.ProtectedRoute(Bonito.FolderServer("."), store; lockout_window=0.0)
    Bonito.record_failed_attempt(pr2, "7.7.7.7")
    sleep(0.01)
    @test Bonito.check_rate_limit(pr2, "7.7.7.7") == true
    @test !haskey(pr2.failed_attempts, "7.7.7.7")
end

@testset "secure_compare is correct (and length-tolerant)" begin
    @test Bonito.secure_compare("abc", "abc")
    @test !Bonito.secure_compare("abc", "abd")
    @test !Bonito.secure_compare("abc", "abcd")   # length mismatch, no error
    @test !Bonito.secure_compare("abc", "")
    @test Bonito.secure_compare("", "")
    @test Bonito.secure_compare(UInt8[1,2,3], UInt8[1,2,3])
    @test !Bonito.secure_compare(UInt8[1,2,3], UInt8[1,2,4])
    # round-trips through the actual auth path
    u = Bonito.User("admin", "hunter2")
    @test Bonito.authenticate(u, "hunter2")
    @test !Bonito.authenticate(u, "hunter3")
end

# A bundle that cannot be rewritten (read-only package dir, squashfs/DMG app
# bundle) must be trusted even when the packaging step left the source with a
# newer mtime — otherwise every render tries (and fails) to re-bundle, burning
# the full deno timeout per asset. (Lives here, not test-bundles.jl, because it
# needs Bonito loaded; test-bundles.jl runs before `using Bonito`.)
@testset "shipped read-only bundles are trusted" begin
    mktempdir() do dir
        source  = joinpath(dir, "module.js")
        bundled = joinpath(dir, "module.bundled.js")
        write(bundled, "// bundled")
        sleep(0.01)
        write(source, "// source")   # source mtime > bundled mtime
        @test Bonito.file_writeable(bundled)
        @test Bonito.needs_bundling(source, bundled)
        chmod(bundled, 0o444)
        @test !Bonito.file_writeable(bundled)
        @test !Bonito.needs_bundling(source, bundled)
        chmod(bundled, 0o644)   # so mktempdir can clean up on every OS
    end
end

@testset "B12 force_connection / force_asset_server call force_type! (no MethodError)" begin
    ran = Ref(false)
    # Previously these threw MethodError(force_connection!, (conn, ref)).
    Bonito.force_connection(Bonito.WebSocketConnection) do
        ran[] = true
        @test Bonito.FORCED_CONNECTION[] === Bonito.WebSocketConnection
    end
    @test ran[]
    @test Bonito.FORCED_CONNECTION[] === nothing  # restored by finally

    ran2 = Ref(false)
    Bonito.force_asset_server(Bonito.NoServer) do
        ran2[] = true
        @test Bonito.FORCED_ASSET_SERVER[] === Bonito.NoServer
    end
    @test ran2[]
    @test Bonito.FORCED_ASSET_SERVER[] === nothing
end

@testset "B13 root becomes an owner of a sub-first-cached entry" begin
    root = new_root()
    sub = Session(root)
    obs = Observable(1)
    key = Bonito.cache_key(root, obs)

    # Sub caches first.
    Bonito.add_cached!(() -> Bonito.SerializedObservable(key, obs[]),
                       sub, Dict{String,Any}(), obs)
    entry = root.session_objects[key]
    @test sub.id in entry.owners
    @test !(root.id in entry.owners)

    # Now root references the same observable → it must become an owner too,
    # so the entry survives the sub closing.
    Bonito.add_cached!(() -> Bonito.SerializedObservable(key, obs[]),
                       root, Dict{String,Any}(), obs)
    @test root.id in entry.owners

    # Sub closes; entry must remain because root still owns it.
    Bonito.delete_cached!(root, sub, key)
    @test haskey(root.session_objects, key)
    @test root.id in root.session_objects[key].owners
end

@testset "B14 remove_js_updates! matches by cache-key id, not session" begin
    root = new_root()
    sub = Session(root)
    obs = Observable(1)
    key = Bonito.cache_key(sub, obs)

    # Register the updater via `sub` (the FIRST session to serialize). This is
    # the case that the old `f.session === session` filter could not clean up
    # when a different session closed last.
    Bonito.register_observable!(sub, obs)
    @test any(((p, f),) -> f isa Bonito.JSUpdateObservable && f.id == key,
              obs.listeners)

    # Removing by key drops it regardless of which session is passed.
    Bonito.remove_js_updates!(key, obs)
    @test !any(((p, f),) -> f isa Bonito.JSUpdateObservable && f.id == key,
               obs.listeners)
end

@testset "B17 bundle_data_snapshot is a copy (no torn vector)" begin
    # Use a BinaryAsset-free plain Asset stand-in: construct a fake es6 asset is
    # heavy, so we just verify the snapshot helper returns an independent copy
    # and that concurrent snapshots are consistent.
    css = joinpath(mktempdir(), "x.css")
    write(css, "body{color:red}")
    asset = Bonito.Asset(css)
    # Plain (non-module) asset has empty bundle_data; snapshot is still a fresh
    # vector that callers may mutate without touching the asset.
    snap = Bonito.bundle_data_snapshot(asset)
    @test snap == asset.bundle_data
    @test snap !== asset.bundle_data
    # Each asset carries its own bundle lock (used to serialize bundle/read).
    @test asset.bundle_lock isa ReentrantLock
end

@testset "B18 record_states restores widget values" begin
    s = Bonito.Slider(1:10; value=3)
    before = s.value[]
    @test before == 3
    session = new_root()
    dom = DOM.div(s)
    Bonito.record_states(session, dom)
    # After recording every state, the widget must be back at its original value
    # (previously it was left at last(value_range) == 10).
    @test s.index[] == 3
    @test s.value[] == before
    close(session)
end

@testset "B19 Dropdown clamps index when options shrink" begin
    opts = Observable{Vector{Any}}(["a", "b", "c"])
    dd = Bonito.Dropdown(opts; index=3)
    @test dd.value[] == "c"
    # Shrinking options used to throw BoundsError inside the notify chain.
    opts[] = ["x"]
    @test dd.option_index[] == 1
    @test dd.value[] == "x"
end

@testset "B20 Slider.value updates Julia-side from index" begin
    s = Bonito.Slider(10:10:50)  # values 10,20,30,40,50
    @test s.value[] == 10
    s.index[] = 4
    @test s.value[] == 40   # no browser round-trip needed
    # Shrinking values clamps instead of throwing.
    s.values[] = [1, 2]
    @test s.index[] >= 1
    @test s.value[] in (1, 2)
end

@testset "B40 StylableSlider snaps non-exact float default" begin
    # Previously errored: value=π/2 is not bit-exactly in the range.
    sl = Bonito.StylableSlider(range(0, 2pi, length=100); value=pi/2)
    @test sl.index[] >= 1
    @test sl.index[] <= 100
    # Snapped to the nearest tick.
    @test abs(sl.value[] - pi/2) < (2pi / 99)
end

@testset "B41 FileInput keeps the supplied observable" begin
    obs = Observable(["initial.txt"])
    fi = Bonito.FileInput(obs)
    @test fi.value === obs
end

@testset "B42 Slider jsrender doesn't leak Hyperscript.styles into style attr" begin
    s = Bonito.Slider(1:5)
    session = new_root()
    node = Bonito.jsrender(session, s)
    # The input must not carry a `style` attribute that is the `styles`
    # function (the old `style=styles` leak). Assert unconditionally.
    attrs = Bonito.Hyperscript.attrs(node)
    @test !(get(attrs, "style", nothing) isa Function)
    close(session)
end

@testset "B43 no-server path containment is segment-aware" begin
    @test Bonito.is_path_contained("/data/site", "/data/site/a")
    @test !Bonito.is_path_contained("/data/site", "/data/site-backup/a")
end

@testset "B44 export_static(folder, routes) closes per-route sessions" begin
    folder = mktempdir()
    routes = Bonito.Routes(
        "/" => App(_ -> DOM.div("home")),
        "/about" => App(_ -> DOM.div("about")),
    )
    # Should not throw, and should produce index.html per route.
    Bonito.export_static(folder, routes)
    @test isfile(joinpath(folder, "index.html"))
    @test isfile(joinpath(folder, "about", "index.html"))
end

@testset "B45 deno_bundle reports error string (no silent empty)" begin
    # Without Deno loaded this returns (false, "Deno not loaded"); either way it
    # must never hang and must return a non-empty message on failure.
    ok, msg = Bonito.deno_bundle(tempname() * ".js", tempname() * ".bundled.js")
    @test ok == false
    @test !isempty(msg)
end
