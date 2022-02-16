
# MsgPack doesn't natively support Float16
MsgPack.msgpack_type(::Type{Float16}) = MsgPack.FloatType()
MsgPack.to_msgpack(::MsgPack.FloatType, x::Float16) = Float32(x)
# taken from MsgPack docs... Did I miss a type that natively supports this?
struct ByteVec{T}
    bytes::T
end
Base.length(bv::ByteVec) = sizeof(bv.bytes)
Base.write(io::IO, bv::ByteVec) = write(io, bv.bytes)
Base.:(==)(a::ByteVec, b::ByteVec) = a.bytes == b.bytes
MsgPack.msgpack_type(::Type{<:ByteVec}) = MsgPack.BinaryType()
MsgPack.to_msgpack(::MsgPack.BinaryType, x::ByteVec) = x
MsgPack.from_msgpack(::Type{ByteVec}, bytes::Vector{UInt8}) = ByteVec(bytes)

function to_bytevec(array::AbstractVector{T}) where T
    return ByteVec(convert(Vector{T}, array))
end

function to_data_url(file_path; mime = file_mimetype(file_path))
    isfile(file_path) || error("File not found: $(file_path)")
    return sprint() do io
        print(io, "data:$(mime);base64,")
        iob64_encode = Base64EncodePipe(io)
        open(file_path, "r") do io
            write(iob64_encode, io)
        end
    end
end

function serialize_string(session::Session, @nospecialize(obj))
    binary = serialize_binary(session, obj)
    return Base64.base64encode(binary)
end

function serialize_binary(session::Session, @nospecialize(obj))
    context = SerializationContext([], session.url_serializer)
    data = serialize_js(context, obj) # apply custom, overloadable transformation
    return transcode(GzipCompressor, MsgPack.pack(data))
end

function deserialize_binary(bytes::AbstractVector{UInt8})
    message_msgpacked = transcode(GzipDecompressor, bytes)
    return MsgPack.unpack(message_msgpacked)
end

function js_type(type::String, @nospecialize(x))
    return Dict(
        "__javascript_type__" => type,
        "payload" => x
    )
end

serialize_js(@nospecialize(x)) = x

"""
Will insert julia values by value into e.g. js
```Julia
js"console.log(\$(by_value(observable)))"
--> {id: "xxx", value: the_value}
js"console.log(\$(observable))"
--> "xxx" # will be just the id to reference the observable
```
"""
function by_value(x::Observable)
    obs_val = Dict(:id => x.id, :value => x[])
    return js_type("Observable", obs_val)
end

by_value(@nospecialize(x)) = x

function by_value(node::Hyperscript.Node{Hyperscript.HTMLSVG})
    vals = Dict(
        "tag" => getfield(node, :tag),
        "children" => by_value.(getfield(node, :children))
    )
    merge!(vals, getfield(node, :attrs))
    return vals
end

serialize_js(x::Observable) = string(x.id)

function serialize_js(node::Node)
    return js_type("DomNode", uuid(node))
end

function serialize_js(x::Union{AbstractArray, Tuple})
    return map(x-> serialize_js(x), x)
end

function serialize_js(dict::AbstractDict)
    result = Dict()
    for (k, v) in dict
        result[k] = serialize_js(v)
    end
    return result
end

serialize_js(jss::JSString) = jss.source

function serialize_js(jsc::Union{JSCode, JSString})
    context = []
    js_string = sprint(io-> print_js_code(io, jsc, context))
    data = Dict("source" => js_string, "context" => context)
    return js_type("JSCode", data)
end

serialize_js(asset::Asset) = serialize_js(read(asset))

function serialize_js(x::Vector{T}) where {T<:Number}
    return js_type("TypedVector", x)
end

serialize_js(array::AbstractVector{UInt8}) = js_type("Uint8Array", to_bytevec(array))
serialize_js(array::AbstractVector{Int32}) = js_type("Int32Array", to_bytevec(array))
serialize_js(array::AbstractVector{UInt32}) = js_type("Uint32Array", to_bytevec(array))
serialize_js(array::AbstractVector{Float16}) = serialize_js(convert(Vector{Float32}, array))
serialize_js(array::AbstractVector{Float32}) = js_type("Float32Array", to_bytevec(array))
serialize_js(array::AbstractVector{Float64}) = js_type("Float64Array", to_bytevec(array))
