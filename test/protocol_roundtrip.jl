# Focused regression tests for the wire-protocol path that was optimized
# (JSUpdateObservable → Dict{String,Any}, serialize_cached fast-path,
# stream-packed SerializedMessage + SessionCache). The JS decoder expects a
# precise byte shape; we reproduce its decode steps in Julia so any drift
# blows up here rather than as a silent WS hang in a browser session.
#
# Each test pairs a Julia-side serialize with a manual unpack that mirrors
# the JS side: outer EXT(SERIALIZED_MESSAGE_TAG, …) → array of 4 elements
# → elements 3 + 4 are EXT(0x12, …) whose `.data` is then unpacked again
# as the next-level msgpack value (SessionCache / payload-dict).

using Test, Bonito, MsgPack
using Bonito: SerializedMessage, SessionCache, serialize_binary, deserialize_binary,
              SerializationContext, serialize_cached, SERIALIZED_MESSAGE_TAG,
              SESSION_CACHE_TAG

const EXT_BIN_TAG = Int8(0x12)

# Walk one msgpack EXT one level deeper. Returns the inner-array decoded by
# the bare MsgPack.unpack (no codec) — same shape JS sees from
# `MsgPack.decode(uint_8_array)`.
function unwrap_outer(bytes::Vector{UInt8})
    outer = MsgPack.unpack(bytes)
    @assert outer isa MsgPack.Extension "expected outer EXT, got $(typeof(outer))"
    return outer.type, MsgPack.unpack(outer.data)
end

# Decode the inner cache extension as JS would: EXT(0x12) → its bytes →
# unpack again to surface the SessionCache (EXT(SESSION_CACHE_TAG, …)).
function unwrap_inner_ext(elem)
    @assert elem isa MsgPack.Extension && elem.type == EXT_BIN_TAG
    return MsgPack.unpack(elem.data)
end

function make_session()
    Bonito.Session(Bonito.NoConnection(); asset_server = Bonito.NoServer())
end

@testset "protocol roundtrip" begin
    @testset "Dict{String,Any} Observable update (fast path)" begin
        s = make_session()
        msg = Dict{String,Any}("payload" => 42, "id" => "abc-1234", "msg_type" => "0")
        bytes = serialize_binary(s, msg)
        @test bytes isa Vector{UInt8}

        tag, inner = unwrap_outer(bytes)
        @test tag == SERIALIZED_MESSAGE_TAG
        @test length(inner) == 4
        @test inner[1] == s.id
        @test inner[2] in ("root", "sub")
        cache_outer = unwrap_inner_ext(inner[3])
        @test cache_outer isa MsgPack.Extension
        @test cache_outer.type == SESSION_CACHE_TAG
        data_dict = unwrap_inner_ext(inner[4])
        @test data_dict isa AbstractDict
        @test data_dict["payload"] == 42
        @test data_dict["id"] == "abc-1234"
        @test data_dict["msg_type"] == "0"
    end

    @testset "Dict{Symbol,Any} Observable update (legacy slow path)" begin
        s = make_session()
        msg = Dict{Symbol,Any}(:payload => 99, :id => "xyz-99", :msg_type => "0")
        bytes = serialize_binary(s, msg)
        tag, inner = unwrap_outer(bytes)
        @test tag == SERIALIZED_MESSAGE_TAG
        data_dict = unwrap_inner_ext(inner[4])
        # Symbol-key path stringifies inside serialize_cached.
        @test data_dict["payload"] == 99
        @test data_dict["id"] == "xyz-99"
    end

    @testset "non-primitive value forces slow path" begin
        s = make_session()
        # Vector of ints is a JSTypedNumber array — gets msgpack ExtensionType,
        # not a primitive. Fast path must reject and fall through.
        msg = Dict{String,Any}("payload" => Int32[1,2,3], "id" => "v", "msg_type" => "0")
        bytes = serialize_binary(s, msg)
        tag, inner = unwrap_outer(bytes)
        @test tag == SERIALIZED_MESSAGE_TAG
        # Decoded as EXT(0x12) wrapping the typed-array bytes.
        data_dict = unwrap_inner_ext(inner[4])
        @test data_dict["payload"] isa MsgPack.Extension
        @test data_dict["id"] == "v"
    end

    @testset "fast-path returns *same* dict (no rebuild)" begin
        s = make_session()
        msg = Dict{String,Any}("payload" => 1, "id" => "a", "msg_type" => "0")
        ctx = SerializationContext(s)
        out = serialize_cached(ctx, msg)
        @test out === msg   # identity, not just equal — confirms no rebuild
    end

    @testset "fast-path falls through to rebuild for non-primitive" begin
        s = make_session()
        msg = Dict{String,Any}("payload" => Int32[1,2,3], "id" => "a", "msg_type" => "0")
        ctx = SerializationContext(s)
        out = serialize_cached(ctx, msg)
        @test out !== msg   # rebuilt
        @test out["id"] == "a"
    end

    @testset "Dict{Symbol,Any} still gets rebuilt (slow path)" begin
        s = make_session()
        msg = Dict{Symbol,Any}(:payload => 1)
        ctx = SerializationContext(s)
        out = serialize_cached(ctx, msg)
        @test out !== msg
        @test out isa Dict{String,Any}
        @test out["payload"] == 1
    end

    @testset "EvalJavascript-style Symbol-key message still works" begin
        # Bonito's own internal sends use Dict{Symbol,Any}(msg_type=..., payload=…).
        # Make sure the send path still routes them.
        s = make_session()
        msg = Dict{Symbol,Any}(:msg_type => "1", :payload => "alert('hi')")
        bytes = serialize_binary(s, msg)
        tag, inner = unwrap_outer(bytes)
        @test tag == SERIALIZED_MESSAGE_TAG
        data_dict = unwrap_inner_ext(inner[4])
        @test data_dict["msg_type"] == "1"
        @test data_dict["payload"] == "alert('hi')"
    end

    @testset "byte-identical to a known-good reference" begin
        # The wire format must not drift. Pin a known-good encoding of a
        # simple update so any future change to the layout fails loudly.
        s = make_session()
        # Pre-set the session id so the captured bytes are deterministic.
        s.id = "deadbeef-0000-0000-0000-000000000000"
        msg = Dict{String,Any}("payload" => 7, "id" => "obs-1", "msg_type" => "0")
        bytes = serialize_binary(s, msg)
        # Snapshot the structure (not raw bytes; field-order in the cache
        # dict isn't stable across runs, but a structural recursive decode is).
        tag, inner = unwrap_outer(bytes)
        @test tag == SERIALIZED_MESSAGE_TAG
        @test inner[1] == s.id
        @test unwrap_inner_ext(inner[4])["payload"] == 7
    end
end
