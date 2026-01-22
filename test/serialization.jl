using Bonito: Observable, Retain, CacheKey, decode_extension_and_addbits
using Bonito: SerializationContext, serialize_cached, SessionCache
using Bonito, MsgPack, Test

@testset "nested observable serialization order" begin
    # Test that nested observables are serialized in dependency order:
    # inner observables must come before outer observables that reference them via CacheKey.
    # This is critical for static export where JS deserializes the cache and needs to
    # resolve CacheKey references during unpacking.

    session = Bonito.Session(Bonito.NoConnection(); asset_server=Bonito.NoServer())

    inner_a = Observable(rand(3))
    inner_b = Observable(rand(3))
    outer_obs = Observable(Dict("a" => inner_a, "b" => inner_b))

    # Serialize JSCode that references the outer observable
    jscode = js"const x = $(outer_obs)"
    ctx = SerializationContext(session)
    serialize_cached(ctx, jscode)

    # Create SessionCache and do MsgPack round-trip
    cache = SessionCache(session, ctx.message_cache)
    packed = MsgPack.pack(cache)
    unpacked_ext = MsgPack.unpack(packed)
    # Structure: [session_id, session_status, packed_objects_ext]
    # packed_objects_ext is Extension(18) containing packed bytes
    session_id, session_status, packed_objects_ext = MsgPack.unpack(unpacked_ext.data)
    objs_array = MsgPack.unpack(packed_objects_ext.data)

    # objs_array is [value, ...] where values are Observable extensions.
    # Extract the observable id from each extension's data.
    function get_obs_id(ext::MsgPack.Extension)
        # Observable extension data is packed [id, value]
        id_value = MsgPack.unpack(ext.data)
        return id_value[1]
    end

    # Verify order: inner observables should come before outer
    inner_ids = Set([inner_a.id, inner_b.id])
    outer_id = outer_obs.id

    obs_ids = [get_obs_id(obj) for obj in objs_array if obj isa MsgPack.Extension && obj.type == Int8(101)]
    inner_positions = [i for (i, id) in enumerate(obs_ids) if id in inner_ids]
    outer_position = findfirst(id -> id == outer_id, obs_ids)

    @test length(inner_positions) == 2
    @test !isnothing(outer_position)
    @test all(p < outer_position for p in inner_positions)

    close(session)
end

@testset "MsgPack" begin
    data = [
        Observable([1, Dict("a" => rand(1000))]),
        Dict(:a => rand(Float32, 1000), "b" => rand(Float16, 10^6)),
        rand(Int, 100),
        [rand(12), Retain(Observable([2,3,4])), CacheKey("kdjaksjd")]
    ]

    unpacked = Bonito.decode_extension_and_addbits(MsgPack.unpack(MsgPack.pack(data)))
    @test data[1].val == unpacked[1].val
    @test data[2][:a] == unpacked[2]["a"]
    @test data[2]["b"] == unpacked[2]["b"]

    @test data[3] == unpacked[3]
    @test data[4][1] == unpacked[4][1]
    @test data[4][2].value.val == unpacked[4][2].value.val
    @test data[4][3] == unpacked[4][3]
end

# Arrays

@testset "typed array serialization" begin
    data = Dict{String, Array}()
    for T in [Int8, UInt8, Int16, UInt16, Int32, UInt32, Float16, Float32, Float64]
        data["vec_$(T)"] = rand(T, 100)
        data["mat_$(T)"] = rand(T, 100, 100)
        data["vol_$(T)"] = rand(T, 100, 100, 100)

        data["v_vec_$(T)"] = view(data["vec_$(T)"], 5:10)
        data["v_mat_$(T)"] = view(data["mat_$(T)"], 5:10, 5:10)
        data["v_vol_$(T)"] = view(data["vol_$(T)"], 5:10, 5:10, 5:10)
    end
    @testset "round tripping arrays in Julia" begin
        round_tripped = MsgPack.unpack(MsgPack.pack(data))
        for (key, value) in round_tripped
            @test value isa MsgPack.Extension
            if occursin("vec", key)
            else
                @test value.type == 99
            end
        end
    end

    @testset "round tripping arrays in JS" begin
        handler(args...) = DOM.div()
        testsession(handler, port=8558) do app
            roundtripped_js = evaljs(app, js"""$data""")

            for (key, value) in roundtripped_js
                @test value isa MsgPack.Extension
                if !occursin("vec", key)
                    @test value.type == 99
                end
            end
            decoded = decode_extension_and_addbits(roundtripped_js)
            @test decoded == data
        end
    end
end
