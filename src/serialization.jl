struct SerializationContext
    message_cache::Dict{String, Any}
    session::Session
end

function SerializationContext(session::Session)
    return SerializationContext(Dict{String, Any}(), session)
end

struct CacheKey
    key::String
end

struct Retain
    value::Any
end

object_identity(retain::Retain) = object_identity(retain.value)

function serialize_cached(context::SerializationContext, retain::Retain)
    if isnothing(object_identity(retain))
        error("Can only retain types with `JSServe.object_identity`. To fix, overload `JSServe.object_identity(x::$(typeof(value)))` to return a unique value")
    end
    return add_cached!(context.session, context.message_cache, retain) do
        return retain
    end
end

struct SerializedAsset
    es6module::Bool
    url::String
end

function serialize_cached(context::SerializationContext, asset::Asset)
    bundle!(asset) # no-op if not needed
    return add_cached!(context.session, context.message_cache, asset) do
        return SerializedAsset(asset.es6module, url(context.session.asset_server, asset))
    end
end

struct SerializedObservable
    id::String
    value::Any
end

function serialize_cached(context::SerializationContext, obs::Observable)
    return add_cached!(context.session, context.message_cache, obs) do
        root = root_session(context.session)
        updater = JSUpdateObservable(root, obs.id)
        deregister = on(updater, root, obs)
        push!(context.session.deregister_callbacks, deregister)
        return SerializedObservable(obs.id, serialize_cached(context, obs[]))
    end
end

struct SerializedJSCode
    interpolated_objects::Dict{String, Any}
    source::String
    julia_file::String
end

function serialize_cached(context::SerializationContext, js::JSCode)
    objects = IdDict()
    # Print code while collecting all interpolated objects in an IdDict
    code = sprint() do io
        print_js_code(io, js, objects)
    end
    # reverse lookup and serialize elements
    interpolated_objects = Dict{String, Any}(v => serialize_cached(context, k) for (k, v) in objects)
    return SerializedJSCode(
        interpolated_objects,
        code,
        js.file
    )
end

function serialize_cached(context::SerializationContext, node::Node{Hyperscript.HTMLSVG})
    return SerializedNode(context.session, node)
end

object_identity(asset::Asset) = unique_file_key(asset)
object_identity(observable::Observable) = observable.id
object_identity(@nospecialize(observable)) = nothing

function serialize_cached(context::SerializationContext, @nospecialize(obj))
    key = object_identity(obj)
    # if key is nothing it means we can't/ don't want to cache!
    isnothing(key) && return obj
    return add_cached!(context.session, context.message_cache, obj) do
        obj
    end
end

function serialize_cached(context::SerializationContext, x::Union{AbstractArray, Tuple})
    result = Vector{Any}(undef, length(x))
    @inbounds for (i, elem) in enumerate(x)
        result[i] = serialize_cached(context, elem)
    end
    return result
end

function serialize_cached(context::SerializationContext, dict::AbstractDict)
    result = Dict{String, Any}()
    for (k, v) in dict
        result[string(k)] = serialize_cached(context, v)
    end
    return result
end

struct SessionCache
    session_id::String
    objects::Dict{String, Any}
end

function serialize_cached(session::Session, @nospecialize(obj))
    ctx = SerializationContext(session)
    data = serialize_cached(ctx, obj)
    return [SessionCache(session.id, ctx.message_cache), data]
end

# We want typed arrays to arrive as JS typed arrays
const JSTypedArrayEltypes = [Int8, UInt8, Int16, UInt16, Int32, UInt32, Float32, Float64]
const JSTypedNumber = Union{JSTypedArrayEltypes...}

const MSGPACK_NATIVE_TYPES = Union{
    CacheKey,
    Retain,
    SerializedJSCode,
    SerializedAsset,
    Observable,
    AbstractVector{<: JSTypedNumber}
}

serialize_cached(::SerializationContext, native::MSGPACK_NATIVE_TYPES) = native
serialize_cached(::SerializationContext, native::AbstractVector{<: Number}) = native

function serialize_binary(session::Session, @nospecialize(obj))
    data = serialize_cached(session, obj)
    return transcode(GzipCompressor, MsgPack.pack(data))
end

function serialize_binary(session::Session, msg::SerializedMessage)
    return transcode(GzipCompressor, MsgPack.pack(msg))
end

function serialize_string(session::Session, @nospecialize(obj))
    binary = serialize_binary(session, obj)
    return Base64.base64encode(binary)
end

function deserialize_binary(bytes::AbstractVector{UInt8})
    message_msgpacked = transcode(GzipDecompressor, bytes)
    return MsgPack.unpack(message_msgpacked)
end
