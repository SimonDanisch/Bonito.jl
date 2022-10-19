struct SerializationContext
    session_cache::OrderedDict{String, Any}
    observables::Dict{String, Observable}
    session::Session
end

function SerializationContext(session_cache=OrderedDict{String, Any}())
    return SerializationContext(session_cache, Dict{String, Observable}())
end

function SerializationContext(session::Session)
    return SerializationContext(session.session_cache, session.observables, session)
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

serialize_js(@nospecialize(x)) = x
serialize_js(array::AbstractVector{T}) where {T<:Number} = js_type("TypedVector", array)
serialize_js(array::AbstractVector{UInt8}) = js_type("Uint8Array", to_bytevec(array))
serialize_js(array::AbstractVector{Int32}) = js_type("Int32Array", to_bytevec(array))
serialize_js(array::AbstractVector{UInt32}) = js_type("Uint32Array", to_bytevec(array))
serialize_js(array::AbstractVector{Float16}) = serialize_js(convert(Vector{Float32}, array))
serialize_js(array::AbstractVector{Float32}) = js_type("Float32Array", to_bytevec(array))
serialize_js(array::AbstractVector{Float64}) = js_type("Float64Array", to_bytevec(array))

function serialize_cached(context::SerializationContext, asset::Asset)
    id = object_identity(asset)
    get!(context.session_cache, id) do
        return js_type("Asset", Dict(:es6module => asset.es6module, :url => url(context.session.asset_server, asset)))
    end
    return js_type("CacheKey", id)
end


function serialize_cached(context::SerializationContext, obs::Observable)
    context.observables[obs.id] = obs
    get!(context.session_cache, obs.id) do
        updater = JSUpdateObservable(context.session, obs.id)
        on(updater, context.session, obs)
        js_type("Observable", Dict(:id => obs.id, :value => serialize_cached(context, obs[])))
    end
    return js_type("CacheKey", obs.id)
end

function serialize_cached(context::SerializationContext, js::JSCode)
    objects = IdDict()
    # Print code while collecting all interpolated objects in an IdDict
    code = sprint() do io
        print_js_code(io, js, objects)
    end
    # reverse lookup and serialize elements
    interpolated_objects = Dict(v => serialize_cached(context, k) for (k, v) in objects)
    data = Dict(
        :interpolated_objects => interpolated_objects,
        :source => code,
        :julia_file => js.file
    )
    return js_type("JSCode", data)
end

function serialize_cached(context::SerializationContext, node::Hyperscript.Node{Hyperscript.HTMLSVG})
    vals = Dict(
        "tag" => getfield(node, :tag),
        "children" => serialize_cached(context, getfield(node, :children))
    )
    merge!(vals, serialize_cached(context, getfield(node, :attrs)))
    return js_type("DomNodeFull", vals)
end

object_identity(asset::Asset) = unique_file_key(asset)
object_identity(observable::Observable) = observable.id
object_identity(@nospecialize(observable)) = nothing

function serialize_cached(context::SerializationContext, @nospecialize(obj))
    id = object_identity(obj)
    # if id is nothing it means we can't/ don't want to cache!
    isnothing(id) && return serialize_js(obj)
    get!(context.session_cache, id) do
        serialize_js(obj)
    end
    return js_type("CacheKey", id)
end

function serialize_cached(context::SerializationContext, x::Union{AbstractArray, Tuple})
    serialized = serialize_js(x)
    if serialized === x
        return map(x-> serialize_cached(context, x), x)
    else
        return serialized
    end
end

function serialize_cached(context::SerializationContext, dict::AbstractDict)
    result = Dict()
    for (k, v) in dict
        result[k] = serialize_cached(context, v)
    end
    return result
end

function serialize_cached(session::Session, @nospecialize(obj))
    ctx = SerializationContext(OrderedDict{String, Any}(), session.observables, session)
    # we merge all objects into one dict
    # Since we don't reuse the message_cache dict, we can just merge it into that:
    # apply custom, overloadable transformation
    data = serialize_cached(ctx, obj)
    # session_cache = OrderedDict{String, Any}()
    # for (k, obj) in ctx.session_cache
    #     if !haskey(session.session_cache, k)
    #         session_cache[k] = obj
    #         session.session_cache[k] = obj
    #     else
    #         # if already cached, we dont send it again
    #         # but we need to declare it, so that we can do refcounting
    #         session_cache[k] = nothing
    #     end
    # end

    return Dict(
        :session_id => session.id,
        :session_cache => ctx.session_cache,
        :data => data)
end

function serialize_binary(session::Session, @nospecialize(obj))
    data = serialize_cached(session, obj)
    return transcode(GzipCompressor, MsgPack.pack(data))
end
