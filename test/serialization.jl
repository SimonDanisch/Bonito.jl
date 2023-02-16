using JSServe: Observable, Retain, CacheKey, decode_extension_and_addbits
using JSServe, MsgPack, Test

@testset "MsgPack" begin
    data = [
        Observable([1, Dict("a" => rand(1000))]),
        Dict(:a => rand(Float32, 1000), "b" => rand(Float16, 10^6)),
        rand(Int, 100),
        [rand(12), Retain(Observable([2,3,4])), CacheKey("kdjaksjd")]
    ]

    unpacked = JSServe.decode_extension_and_addbits(MsgPack.unpack(MsgPack.pack(data)))
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
