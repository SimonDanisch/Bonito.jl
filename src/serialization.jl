struct SerializationContext
    content_identity::Dict{String, Any}
    pointer_identity::Dict{String, Any}
end

function SerializationContext(content_identity=Dict{String, Any}())
    return SerializationContext(content_identity, Dict{String, Any}())
end

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

function serialize_cached(context::SerializationContext, jsc::Union{JSCode, JSString})
    js_string = sprint(io-> print_js_code(io, jsc, context))
    return js_type("JSCode", js_string)
end

serialize_js(@nospecialize(x)) = x
serialize_js(node::Node) = js_type("DomNode", uuid(node))
serialize_js(observable::Observable) = string(observable.id)
serialize_js(asset::Asset) = js_type("Asset", read(get_path(asset)))
serialize_js(array::AbstractVector{T}) where {T<:Number} = js_type("TypedVector", array)
serialize_js(array::AbstractVector{UInt8}) = js_type("Uint8Array", to_bytevec(array))
serialize_js(array::AbstractVector{Int32}) = js_type("Int32Array", to_bytevec(array))
serialize_js(array::AbstractVector{UInt32}) = js_type("Uint32Array", to_bytevec(array))
serialize_js(array::AbstractVector{Float16}) = serialize_js(convert(Vector{Float32}, array))
serialize_js(array::AbstractVector{Float32}) = js_type("Float32Array", to_bytevec(array))
serialize_js(array::AbstractVector{Float64}) = js_type("Float64Array", to_bytevec(array))

function pointer_identity(@nospecialize(x::Union{AbstractString, AbstractArray}))
    return string(UInt64(pointer(x)))
end

function pointer_identity(@nospecialize(obj))
    # immutable objects have no pointer identity
    isimmutable(obj) && return nothing
    return string(UInt64(pointer_from_objref(obj)))
end

function object_identity(@nospecialize(obj))
    return :pointer_identity, pointer_identity(obj)
end

struct CacheKey
    id::String
end

MsgPack.msgpack_type(::Type{CacheKey}) = MsgPack.MapType()
MsgPack.to_msgpack(::MsgPack.StringType, x::CacheKey) = jstype("CacheKey", x.id)

function serialize_cached(context::SerializationContext, obj)
    method, id = object_identity(obj)
    # if id is nothing it means we can't cache!
    isnothing(id) && return obj
    dict = getfield(context, method)
    get!(dict, id) do
        serialize_js(obj)
    end
    return CacheKey(id)
end

function serialize_cached(context::SerializationContext, x::Union{AbstractArray, Tuple})
    return map(x-> serialize_cached(context, x), x)
end

function serialize_cached(context::SerializationContext, dict::AbstractDict)
    result = Dict()
    for (k, v) in dict
        result[k] = serialize_cached(context, v)
    end
    return result
end

function serialize_cached(session::Session, @nospecialize(obj))
    content_id = copy(session.content_identity)
    context = SerializationContext(content_id)
    # we merge all objects into one dict
    # Since we don't reuse the pointer_identity dict, we can just merge it into that:
    # apply custom, overloadable transformation
    data = serialize_cached(context, obj)
    for (k, obj) in session.content_identity
        delete!(content_id, k)
    end
    objects = merge!(context.pointer_identity, content_id)
    return Dict(:objects => objects, :data => data)
end

function serialize_binary(session::Session, @nospecialize(obj))
    data = serialize_cached(session, obj)
    return transcode(GzipCompressor, MsgPack.pack(data))
end
