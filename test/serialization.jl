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


@testset "Serialization format" begin
    session = Session()
    test = "heyyyy"
    doms = [DOM.div("hey"), DOM.h1("heydude")]
    dublicate = rand(1000, 1000)
    data = Dict(
        "array" => [1,2,3,4,5],
        "obsies" => [Observable(1), Observable([1,2,3,4])],
        "tuples" => (1,2,3,4),
        "double" => dublicate,
        "nested" => Dict(
            :symbols! => "string",
            :unicode => "πϕ♋",
            :node_array => doms,
            :jscode => js"heyy($(test))",
            :moah_nesting => dublicate
        )
    )

    bytes = serialize_binary(session, data)
    data_unpacked = MsgPack.unpack(transcode(GzipDecompressor, bytes))
    @test haskey(session.unique_object_cache, duplicate_id)
    @test isempty(data_unpacked["update_cache"]["to_remove"])
    @test length(data_unpacked["update_cache"]["to_register"]) == 1
    @test first(keys(data_unpacked["update_cache"]["to_register"])) == duplicate_id

    @test data_unpacked["data"]["nested"]["jscode"]["payload"]["source"] == "heyy('$(test)')"
    @test data_unpacked["data"]["nested"]["unicode"] == "πϕ♋"
    @test data_unpacked["data"]["nested"]["node_array"][1] == js_type("DomNode", uuid(doms[1]))
    @test data_unpacked["data"]["nested"]["node_array"][2] == js_type("DomNode", uuid(doms[2]))
    @test data_unpacked["data"]["nested"]["jscode"]["payload"]["source"] == "heyy('$(test)')"
    @test data_unpacked["data"]["nested"]["moah_nesting"]["__javascript_type__"] == "Reference"
    @test data_unpacked["data"]["nested"]["moah_nesting"]["payload"] == duplicate_id
    @test data_unpacked["data"]["double"] isa Vector

    bytes2 = serialize_binary(session, data)
    data_unpacked = MsgPack.unpack(transcode(GzipDecompressor, bytes2))
    @test data_unpacked["double"]["__javascript_type__"] == "Reference"
    @test data_unpacked["nested"]["moah_nesting"]["__javascript_type__"] == "Reference"
end


session = Session()
test = "heyyyy"
doms = [DOM.div("hey"), DOM.h1("heydude")]
array = rand(1000, 1000)
data = Dict(
    "array" => [1,2,3,4,5],
    "obsies" => [Observable(1), Observable([1,2,3,4])],
    "tuples" => (1,2,3,4),
    "double" => array,
    "nested" => Dict(
        :symbols! => "string",
        :unicode => "πϕ♋",
        :node_array => doms,
        :jscode => js"heyy($(test))",
        :moah_nesting => array
    )
)

bytes = serialize_binary(session, data)
data_unpacked = MsgPack.unpack(transcode(GzipDecompressor, bytes))
@test data_unpacked["session_id"] == session.id
@test data_unpacked["session_objects"] == session.id

@test haskey(session.unique_object_cache, duplicate_id)
@test isempty(data_unpacked["update_cache"]["to_remove"])
@test length(data_unpacked["update_cache"]["to_register"]) == 1
@test first(keys(data_unpacked["update_cache"]["to_register"])) == duplicate_id

@test data_unpacked["data"]["nested"]["jscode"]["payload"]["source"] == "heyy('$(test)')"
@test data_unpacked["data"]["nested"]["unicode"] == "πϕ♋"
@test data_unpacked["data"]["nested"]["node_array"][1] == js_type("DomNode", uuid(doms[1]))
@test data_unpacked["data"]["nested"]["node_array"][2] == js_type("DomNode", uuid(doms[2]))
@test data_unpacked["data"]["nested"]["jscode"]["payload"]["source"] == "heyy('$(test)')"
@test data_unpacked["data"]["nested"]["moah_nesting"]["__javascript_type__"] == "Reference"
@test data_unpacked["data"]["nested"]["moah_nesting"]["payload"] == duplicate_id
@test data_unpacked["data"]["double"] isa Vector

bytes2 = serialize_binary(session, data)
data_unpacked = MsgPack.unpack(transcode(GzipDecompressor, bytes2))
@test data_unpacked["double"]["__javascript_type__"] == "Reference"
@test data_unpacked["nested"]["moah_nesting"]["__javascript_type__"] == "Reference"
