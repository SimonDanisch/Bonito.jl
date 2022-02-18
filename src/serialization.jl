struct SerializationContext
    session_cache::Dict{String, Any}
    message_cache::Dict{String, Any}
end

function SerializationContext(session_cache=Dict{String, Any}())
    return SerializationContext(session_cache, Dict{String, Any}())
end

function SerializationContext(session::Session)
    return SerializationContext(session.session_cache, Dict{String, Any}())
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

function serialize_cached(context::SerializationContext, obs::Observable)
    get!(context.session_cache, obs.id) do
        js_type("Observable", Dict(:id => obs.id, :value => serialize_cached(context, obs[])))
    end
    return CacheKey(obs.id)
end

function serialize_cached(context::SerializationContext, node::Hyperscript.Node{Hyperscript.HTMLSVG})
    vals = Dict(
        "tag" => getfield(node, :tag),
        "children" => serialize_cached(context, getfield(node, :children))
    )
    merge!(vals, serialize_cached(context, getfield(node, :attrs)))
    return js_type("DomNodeFull", vals)
end

# For JSCode we need the context, since we want to recursively
# cache all interpolated values
function serialize_cached(context::SerializationContext, jsc::Union{JSCode, JSString})
    js_string = sprint(io-> print_js_code(io, jsc, context))
    return js_type("JSCode", js_string)
end

serialize_js(@nospecialize(x)) = x
serialize_js(asset::Asset) = js_type("Asset", Dict(:es6module => asset.es6module, :bytes => serialize_js(read(get_path(asset)))))

serialize_js(array::AbstractVector{T}) where {T<:Number} = js_type("TypedVector", array)
serialize_js(array::AbstractVector{UInt8}) = js_type("Uint8Array", to_bytevec(array))
serialize_js(array::AbstractVector{Int32}) = js_type("Int32Array", to_bytevec(array))
serialize_js(array::AbstractVector{UInt32}) = js_type("Uint32Array", to_bytevec(array))
serialize_js(array::AbstractVector{Float16}) = serialize_js(convert(Vector{Float32}, array))
serialize_js(array::AbstractVector{Float32}) = js_type("Float32Array", to_bytevec(array))
serialize_js(array::AbstractVector{Float64}) = js_type("Float64Array", to_bytevec(array))

function pointer_identity(@nospecialize(x::AbstractArray))
    return string(UInt64(pointer(x)))
end

function pointer_identity(@nospecialize(obj))
    # immutable objects have no pointer identity
    isimmutable(obj) && return nothing
    return string(UInt64(pointer_from_objref(obj)))
end

function object_identity(@nospecialize(obj))
    return :message_cache, pointer_identity(obj)
end

function object_identity(str::String)
    # don't cache strings smaller 520bytes
    # which is the size of CacheKey serialized
    if sizeof(str) < 520
        return :session_cache, nothing
    else
        return :session_cache, string(hash(str))
    end
end

function object_identity(asset::Asset)
    return :session_cache, unique_file_key(asset)
end

function object_identity(observable::Observable)
    return :session_cache, observable.id
end

struct CacheKey
    id::String
end

MsgPack.msgpack_type(::Type{CacheKey}) = MsgPack.MapType()
MsgPack.to_msgpack(::MsgPack.MapType, x::CacheKey) = js_type("CacheKey", x.id)

function serialize_cached(context::SerializationContext, obj)
    method, id = object_identity(obj)
    # if id is nothing it means we can't/ don't want to cache!
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
    content_id = copy(session.session_cache)
    ctx = SerializationContext(content_id)
    # we merge all objects into one dict
    # Since we don't reuse the message_cache dict, we can just merge it into that:
    # apply custom, overloadable transformation
    data = serialize_cached(ctx, obj)
    for (k, obj) in session.session_cache
        delete!(content_id, k)
    end
    return Dict(
        :session_id => session.id,
        :session_cache => content_id,
        :message_cache => ctx.message_cache,
        :data => data)
end

function serialize_binary(session::Session, @nospecialize(obj))
    data = serialize_cached(session, obj)
    return transcode(GzipCompressor, MsgPack.pack(data))
end
