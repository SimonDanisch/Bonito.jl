using JSServe
using JSServe: @js_str, Session, js_type, pointer_identity, uuid, serialize_js, SerializationContext, serialize_binary
using JSServe.DOM
using JSServe.MsgPack
using JSServe.CodecZlib
using Observables
using Test

session = Session()
test = "heyyyy"
doms = [DOM.div("hey"), DOM.h1("heydude")]
dublicate = Dict("x" => rand(100, 100))
duplicate_id = pointer_identity(dublicate)
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

@test data_unpacked["data"]["nested"]["jscode"]["payload"]["source"] == "heyy($(repr(test)))"
@test data_unpacked["data"]["nested"]["unicode"] == "πϕ♋"
@test data_unpacked["data"]["nested"]["node_array"][1] == js_type("DomNode", uuid(doms[1]))
@test data_unpacked["data"]["nested"]["node_array"][2] == js_type("DomNode", uuid(doms[2]))
@test data_unpacked["data"]["nested"]["jscode"]["payload"]["source"] == "heyy($(repr(test)))"
@test data_unpacked["data"]["nested"]["moah_nesting"]["__javascript_type__"] == "Reference"
@test data_unpacked["data"]["nested"]["moah_nesting"]["payload"] == duplicate_id
@test haskey(data_unpacked["data"]["double"], "x")

bytes2 = serialize_binary(session, data)
data_unpacked = MsgPack.unpack(transcode(GzipDecompressor, bytes2))
@test data_unpacked["double"]["__javascript_type__"] == "Reference"
@test data_unpacked["nested"]["moah_nesting"]["__javascript_type__"] == "Reference"


x = [rand(100) for i in 1:50]
data = [x[(i+1)÷2] for i in 1:100]
sum(sizeof, data)
xx = Base.summarysize(data)
session = Session()
bytes2 = serialize_binary(session, data)
bytes2

ctx = SerializationContext(Dict{String, WeakRef}())
xxx = serialize_js(ctx, data)

Base.summarysize(xxx)


MsgPack.pack(xxx) |> sizeof
MsgPack.pack(data) |> sizeof
