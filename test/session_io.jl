# SessionIO end-to-end regression tests.
#
# Covers the runtime invariants the per-session reusable scratch IO relies on,
# in terms an outside observer would notice: byte-identical reuse, no cross-
# session contamination, safe nested SerializedMessage packing, lock-released-
# on-error recovery, and concurrent-task isolation.
#
# These intentionally don't poke at `SessionIO.depth` / `scratches` directly —
# they exercise `Session` + `SerializedMessage` + `serialize_binary` end to end
# the way the WS protocol does, so the test pins observable behavior, not
# implementation details.

using Test, Bonito, MsgPack
using Bonito: Session, NoConnection, NoServer, SerializedMessage, serialize_binary

const _SESSION_IO_DEMO_MSG = Dict{String,Any}(
    "msg_type" => Bonito.UpdateObservable,
    "id" => "obs-1234",
    "payload" => Dict{String,Any}("a" => [1, 2, 3], "b" => "hello", "c" => rand(Float32, 16)),
)

# An unpackable type the slow path will choke on, so we can trigger an error
# halfway through `pack_extension!` and check the scratch state recovers.
struct _Unpackable end

make_io_session() = Session(NoConnection(); asset_server=NoServer())

@testset "SessionIO" begin
    @testset "buffer reuse: identical bytes across repeated sends" begin
        s = make_io_session()
        m = _SESSION_IO_DEMO_MSG
        bytes_first = serialize_binary(SerializedMessage(s, m))
        # Same session, same message — the scratch buffers were grown and reset.
        # The output must not depend on stale bytes left in those scratches.
        bytes_again = serialize_binary(SerializedMessage(s, m))
        @test bytes_first == bytes_again
        # And once more, after a shorter message that doesn't refill the
        # scratches to their high-water mark.
        serialize_binary(SerializedMessage(s, Dict{String,Any}(
            "msg_type" => Bonito.UpdateObservable, "id" => "x", "payload" => 1)))
        @test serialize_binary(SerializedMessage(s, m)) == bytes_first
    end

    @testset "no cross-session contamination" begin
        # Each session tree has its own pack pool. Two independent (root)
        # sessions packing the SAME message in lockstep should both produce
        # their own-session shape and never accidentally share state.
        s1, s2 = make_io_session(), make_io_session()
        m = _SESSION_IO_DEMO_MSG
        # Interleave: pack on s1, s2, s1, s2, s2, s1 — order shouldn't matter.
        b1a = serialize_binary(SerializedMessage(s1, m))
        b2a = serialize_binary(SerializedMessage(s2, m))
        b1b = serialize_binary(SerializedMessage(s1, m))
        b2b = serialize_binary(SerializedMessage(s2, m))
        b2c = serialize_binary(SerializedMessage(s2, m))
        b1c = serialize_binary(SerializedMessage(s1, m))
        @test b1a == b1b == b1c
        @test b2a == b2b == b2c
        # session id is embedded in the payload — sessions must differ.
        @test b1a != b2a
    end

    @testset "Vector{Any} containing SerializedMessage (nested SessionIO entry)" begin
        # When a message that itself contains a fully-built SerializedMessage
        # gets packed (e.g. relaying via export.jl / fused_messages), pack_type
        # for SerializedMessage gets called with `io::SessionIO`, not
        # `io::IOBuffer`. The nested path must use the active SessionIO
        # context, not check a new one out of its captured pool.
        s = make_io_session()
        sm1 = SerializedMessage(s, Dict{String,Any}(
            "msg_type" => Bonito.UpdateObservable, "id" => "a", "payload" => 1))
        sm2 = SerializedMessage(s, Dict{String,Any}(
            "msg_type" => Bonito.UpdateObservable, "id" => "b", "payload" => 2))
        bytes = MsgPack.pack(Any[sm1, sm2])
        decoded = MsgPack.unpack(bytes)
        @test length(decoded) == 2
        @test decoded[1] isa MsgPack.Extension &&
              decoded[1].type == Bonito.SERIALIZED_MESSAGE_TAG
        @test decoded[2] isa MsgPack.Extension &&
              decoded[2].type == Bonito.SERIALIZED_MESSAGE_TAG
    end

    @testset "state recovery after a mid-pack error" begin
        # An unpackable value inside the message makes msgpack throw partway
        # through the outer extension scope. The SessionIO MUST be returned to
        # the pool with its state reset — depth back to 0, scratches reset —
        # otherwise the next message would inherit dirty bytes. The pool lock
        # must also not be left held.
        s = make_io_session()
        bad = Dict{String,Any}(
            "msg_type" => Bonito.UpdateObservable, "id" => "bad", "payload" => _Unpackable())
        sm_bad = SerializedMessage(s, bad)
        @test_throws Exception serialize_binary(sm_bad)
        @test !islocked(s.pack_pool.lock)          # pool lock didn't leak
        # Subsequent good packs work and produce the expected wire shape.
        good = _SESSION_IO_DEMO_MSG
        bytes = serialize_binary(SerializedMessage(s, good))
        @test bytes isa Vector{UInt8}
        outer = MsgPack.unpack(bytes)
        @test outer isa MsgPack.Extension &&
              outer.type == Bonito.SERIALIZED_MESSAGE_TAG
        # And one more — alternating bad/good shouldn't leave scratches dirty.
        @test_throws Exception serialize_binary(SerializedMessage(s, bad))
        @test !islocked(s.pack_pool.lock)
        bytes2 = serialize_binary(SerializedMessage(s, good))
        @test bytes2 == bytes
    end

    @testset "concurrent tasks: pool isolates packs, no corruption" begin
        # Multiple tasks sending on the same Session pack concurrently. Each
        # checks its own SessionIO out of the tree's pool, so they don't share
        # scratch state; a correct implementation produces one valid output per
        # send and never leaves a SessionIO in a half-written state.
        s = make_io_session()
        m = _SESSION_IO_DEMO_MSG
        expected = serialize_binary(SerializedMessage(s, m))
        results = Channel{Vector{UInt8}}(64)
        tasks = [@async begin
            for _ in 1:8
                put!(results, serialize_binary(SerializedMessage(s, m)))
            end
        end for _ in 1:4]
        foreach(wait, tasks)
        close(results)
        all_bytes = collect(results)
        @test length(all_bytes) == 32
        # Every produced message must be byte-identical to the reference —
        # any race would corrupt the shared scratch and produce different bytes.
        @test all(b -> b == expected, all_bytes)
        @test !islocked(s.pack_pool.lock)
    end

    @testset "scratch grows then shrinking message doesn't leak stale bytes" begin
        # Sizehint of the scratch starts at 512B. A 16 KiB Float32 payload
        # forces it to grow. After that, a smaller message must NOT include
        # stale bytes past its real size — reset_for_reuse! must reset
        # io.size / io.ptr, not just truncate (which would keep capacity but
        # also stale data past the new size if size were left untouched).
        s = make_io_session()
        big = Dict{String,Any}(
            "msg_type" => Bonito.UpdateObservable, "id" => "big", "payload" => rand(Float32, 4096))
        small = Dict{String,Any}(
            "msg_type" => Bonito.UpdateObservable, "id" => "s", "payload" => 1)
        bytes_big_first = serialize_binary(SerializedMessage(s, big))
        bytes_small = serialize_binary(SerializedMessage(s, small))
        # Compare to a fresh-session bytes for the same small payload — if
        # stale big bytes leaked, the small-after-big would be longer or
        # have different contents than small-on-a-fresh-session.
        s_fresh = make_io_session()
        # Use the same session id so the embedded id matches.
        s_fresh.id = s.id
        bytes_small_clean = serialize_binary(SerializedMessage(s_fresh, small))
        @test bytes_small == bytes_small_clean
        # And big can still be replayed correctly after going small.
        @test serialize_binary(SerializedMessage(s, big)) == bytes_big_first
    end
end
