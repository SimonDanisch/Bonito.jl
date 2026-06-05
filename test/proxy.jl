# Proxying a session rendered in one process onto another server's page
# (ProxyConnection / ProxyAssetServer / embed_app). These tests use real
# serialization and a capturing connection to drive the full bidirectional path
# without a browser; the browser side is covered by the Electron test in
# various.jl / connection-serving.jl style harnesses.
#
# The mechanism: the browser keys cached objects in one global cache by id, and
# UpdateObservable carries only an id — so worker→browser is a raw byte relay and
# browser→worker is a lookup by id, with worker observable ids namespaced by a
# per-session prefix so they can't collide with the host's.

using Test
using Bonito
using Bonito: Session, App, DOM, Observable, on, onjs, @js_str
using Bonito: embed_app, process_message, deserialize_binary, connection,
              compression_enabled, cache_key, id_prefix, root_session, uuid
using Bonito: ProxyAssetServer, ProxyAssetRegistry, RemoteAsset, read_proxy_asset,
              register_proxy_asset!, release_proxy_asset!, serve_remote_asset,
              unique_file_key, BinaryAsset, url
using Bonito.HTTP: Request, header
using Bonito.MsgPack

# A FrontendConnection that records the bytes destined for the browser.
mutable struct CaptureConnection <: Bonito.FrontendConnection
    frames::Vector{Vector{UInt8}}
end
CaptureConnection() = CaptureConnection(Vector{UInt8}[])
Base.write(c::CaptureConnection, bytes::AbstractVector{UInt8}) = (push!(c.frames, collect(bytes)); nothing)
Base.isopen(::CaptureConnection) = true
Base.close(::CaptureConnection) = nothing
Bonito.setup_connection(::Session{CaptureConnection}) = nothing

# Driver stand-ins for the dispatched proxy verbs (these replace the old closure
# sinks — the test overloads the verbs on tiny driver types).
mutable struct CaptureDriver
    added::Vector{String}
    removed::Vector{String}
end
CaptureDriver() = CaptureDriver(String[], String[])
Bonito.proxy_asset_add(d::CaptureDriver, key, mime, total, cached) = (push!(d.added, key); nothing)
Bonito.proxy_asset_remove(d::CaptureDriver, key) = (push!(d.removed, key); nothing)

struct NoFetchDriver end
Bonito.proxy_fetch(::NoFetchDriver, key, s, e) = error("should not fetch")
struct RangeFetchDriver
    bytes::Vector{UInt8}
end
Bonito.proxy_fetch(d::RangeFetchDriver, key, s, e) = d.bytes[(s+1):(e+1)]

# Decode a SerializedMessage the way the JS side does: EXT(SERIALIZED_MESSAGE_TAG)
# → [session_id, status, cacheExt, dataExt]; the data ext wraps the actual
# message dict. Accepts either raw frame bytes or an already-unpacked extension
# (FusedMessage payload elements are themselves SerializedMessage extensions, so
# this is applied recursively). Returns the decoded message dict (or the bare
# value for non-extension input).
const EXT_BIN_TAG = Int8(0x12)
function decode_sm(x)
    ext = x isa MsgPack.Extension ? x : MsgPack.unpack(x)
    ext isa MsgPack.Extension || return ext
    inner = MsgPack.unpack(ext.data)
    dataext = inner[4]
    return (dataext isa MsgPack.Extension && dataext.type == EXT_BIN_TAG) ?
           MsgPack.unpack(dataext.data) : dataext
end

# Collect every UpdateObservable (id => payload) in a list of captured frames,
# flattening FusedMessage bundles (whose elements are nested SerializedMessages).
function collect_updates(frames)
    out = Pair{String,Any}[]
    for f in frames
        d = decode_sm(f)
        d isa AbstractDict || continue
        if d["msg_type"] == "9"            # FusedMessage
            for sub in get(d, "payload", [])
                m = decode_sm(sub)
                m isa AbstractDict && m["msg_type"] == "0" &&
                    push!(out, m["id"] => m["payload"])
            end
        elseif d["msg_type"] == "0"        # UpdateObservable
            push!(out, d["id"] => d["payload"])
        end
    end
    return out
end

@testset "session proxy" begin

    @testset "namespacing: proxied ids are prefixed, normal ids are not" begin
        normal = Session(CaptureConnection(); compression_enabled=false)
        @test id_prefix(connection(normal)) == ""
        o = Observable(0)
        @test cache_key(normal, o) == o.id          # byte-identical to old behavior
        # normal session: bare dom id + bare subsession id (no regression)
        @test !occursin("/", uuid(normal, DOM.div("x")))
        @test !occursin("/", Session(normal).id)

        host = Session(CaptureConnection(); compression_enabled=false)
        ov = Observable(0)
        app = App() do s; onjs(s, ov, js"(x)=>{}"); DOM.div(DOM.span(ov)); end
        r = embed_app(host, app)
        wkeys = collect(keys(root_session(r.render.session).session_objects))
        @test !isempty(wkeys)
        @test all(k -> startswith(k, r.render.prefix * "/"), wkeys)   # object cache keys
        close(host); close(normal)   # fire embed_app teardown → release proxied assets
    end

    @testset "namespacing covers session ids and dom ids (browser-global)" begin
        host = Session(CaptureConnection(); compression_enabled=false)
        dom_ids = String[]
        content = Observable{Any}(DOM.div("v1"))
        app = App() do s
            push!(dom_ids, uuid(s, DOM.div("hi")))   # dom id minted in the worker session
            return DOM.div(content)                  # Observable{DOM} ⇒ real subsession
        end
        r = embed_app(host, app)
        prefix = r.render.prefix
        wroot = root_session(r.render.session)
        @test wroot.id == prefix                                   # root session id == namespace
        @test all(id -> startswith(id, prefix * "/"), dom_ids)     # dom ids prefixed
        subs = collect(keys(wroot.children))
        @test !isempty(subs)                                       # the Observable made a subsession
        @test all(id -> startswith(id, prefix * "/"), subs)        # subsession ids prefixed
        close(host)
    end

    @testset "two embedded apps get disjoint namespaces" begin
        h1 = Session(CaptureConnection(); compression_enabled=false)
        h2 = Session(CaptureConnection(); compression_enabled=false)
        mk() = App() do s
            o = Observable(0); onjs(s, o, js"(x)=>{}"); DOM.div(DOM.span(o))
        end
        r1 = embed_app(h1, mk()); r2 = embed_app(h2, mk())
        @test r1.render.prefix != r2.render.prefix
        k1 = Set(keys(root_session(r1.render.session).session_objects))
        k2 = Set(keys(root_session(r2.render.session).session_objects))
        @test isempty(intersect(k1, k2))
        close(h1); close(h2)
    end

    @testset "asset refcount: add on 0→1, remove on 1→0, shared across subsessions" begin
        drv = CaptureDriver()
        root_as = ProxyAssetServer(drv)
        sub_as  = similar(root_as)                  # shares the registry
        asset = BinaryAsset(UInt8[1,2,3,4], "application/octet-stream")
        key = unique_file_key(asset)

        url(root_as, asset)
        @test drv.added == [key]                    # 0→1 once
        url(sub_as, asset)
        @test drv.added == [key]                    # 2nd referencing session: no new add
        url(root_as, asset)                          # same session re-reference: no-op
        @test drv.added == [key]

        close(root_as)
        @test isempty(drv.removed)                   # sub still holds a ref
        close(sub_as)
        @test drv.removed == [key]                   # 1→0 once
    end

    @testset "RemoteAsset serves cached bytes and lazy ranges" begin
        bytes = collect(UInt8, 1:20)
        # eager / cached → proxy_fetch must NOT be called
        ra = RemoteAsset("k1", "application/octet-stream", length(bytes), bytes, NoFetchDriver())
        full = serve_remote_asset(Request("GET", "/assets/k1"), ra)
        @test full.status == 200
        @test full.body == bytes
        ranged = serve_remote_asset(Request("GET", "/assets/k1", ["Range" => "bytes=5-9"]), ra)
        @test ranged.status == 206
        @test ranged.body == bytes[6:10]
        @test header(ranged, "Content-Range") == "bytes 5-9/20"

        # lazy: no cached bytes, proxy_fetch pulls the range (mirrors a Malt call)
        fetched = RemoteAsset("k2", "application/octet-stream", length(bytes), nothing, RangeFetchDriver(bytes))
        lazy = serve_remote_asset(Request("GET", "/assets/k2", ["Range" => "bytes=0-3"]), fetched)
        @test lazy.status == 206
        @test lazy.body == bytes[1:4]
    end

    @testset "init bundle ships to the host asset server" begin
        host = Session(CaptureConnection(); compression_enabled=false)
        o = Observable(0)
        app = App() do s; onjs(s, o, js"(x)=>{}"); DOM.div(DOM.span(o)); end
        r = embed_app(host, app)
        @test !isempty(r.render.init_url)
        init_path = split(r.render.init_url, "?")[1]
        parent = host.asset_server.parent
        @test haskey(parent.files, init_path)              # browser can fetch it from the host
        @test occursin(r.render.prefix, r.render.html)      # fragment carries the session wrapper
        close(host)
        @test Bonito.wait_for(() -> !haskey(parent.files, init_path)) == :success  # teardown releases it
    end

    @testset "full round trip: browser update → worker reacts → relayed back" begin
        host = Session(CaptureConnection(); compression_enabled=false)
        clicks  = Observable(0)
        doubled = Observable(0)
        app = App() do s
            on(s, clicks) do c
                doubled[] = 2c
            end
            onjs(s, clicks,  js"(x)=>{}")
            onjs(s, doubled, js"(x)=>{}")
            return DOM.div(DOM.span(doubled))
        end
        r = embed_app(host, app)
        prefix = r.render.prefix
        wsession = r.render.session

        # Browser reports the worker session finished loading → worker goes ready.
        process_message(host, Dict{String,Any}(
            "msg_type" => "8", "session" => prefix, "exception" => "nothing"))
        # on_connection_ready runs async; wait for it.
        tlimit = time() + 5
        while !isready(wsession; throw=false) && time() < tlimit
            sleep(0.02)
        end
        @test isready(wsession; throw=false)

        empty!(connection(host).frames)   # isolate the update relay

        # Browser → worker: update `clicks` (prefixed id), as the browser would send it.
        process_message(host, Dict{String,Any}(
            "msg_type" => "0", "id" => "$(prefix)/$(clicks.id)", "payload" => 5))

        @test clicks[]  == 5      # inbound update reached the real worker observable
        @test doubled[] == 10     # the worker-side reaction fired

        # Worker → browser: the derived update was relayed with the prefixed id.
        updates = collect_updates(connection(host).frames)
        @test ("$(prefix)/$(doubled.id)" => 10) in updates
        close(host)
    end

    @testset "relay is gated on the worker session being ready" begin
        host = Session(CaptureConnection(); compression_enabled=false)
        v = Observable(0); w = Observable(0)
        app = App() do s
            on(s, v) do x
                w[] = x + 1
            end
            onjs(s, v, js"(x)=>{}"); onjs(s, w, js"(x)=>{}")
            return DOM.div(DOM.span(w))
        end
        r = embed_app(host, app); wsession = r.render.session
        empty!(connection(host).frames)

        # Not ready yet (no JSDoneLoading forwarded): the worker reacts, but its
        # outbound update must QUEUE on the worker, not hit the browser — the
        # browser hasn't registered the objects yet.
        process_message(host, Dict{String,Any}(
            "msg_type" => "0", "id" => "$(r.render.prefix)/$(v.id)", "payload" => 7))
        @test w[] == 8                                       # worker reacted
        @test isempty(collect_updates(connection(host).frames))  # but nothing relayed
        @test !isempty(root_session(wsession).message_queue)     # it's queued instead

        # Forward JSDoneLoading → worker flushes the queue to the browser.
        process_message(host, Dict{String,Any}(
            "msg_type" => "8", "session" => r.render.prefix, "exception" => "nothing"))
        # init_session flips ready then flushes on an async task — poll for the frame.
        want = "$(r.render.prefix)/$(w.id)" => 8
        tlimit = time() + 5
        while !(want in collect_updates(connection(host).frames)) && time() < tlimit
            sleep(0.02)
        end
        @test want in collect_updates(connection(host).frames)
        close(host)
    end
end
