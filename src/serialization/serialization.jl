include("types.jl")
include("msgpack.jl")
include("caching.jl")
include("protocol.jl")


function serialize_cached(session::Session, data)
    return lock(root_session(session).deletion_lock) do
        ctx = SerializationContext(session)
        message_data = serialize_cached(ctx, data)
        return (SessionCache(session, ctx.message_cache), message_data)
    end
end

function SerializedMessage(session::Session, data)
    cached_objs, data = serialize_cached(session, data)
    return SerializedMessage(MsgPack.pack(cached_objs), MsgPack.pack(data))
end

function serialize_binary(session::Session, msg::SerializedMessage)
    bytes = MsgPack.pack(msg)
    if session.compression_enabled
        bytes = transcode(GzipCompressor, bytes)
    end
    return bytes
end

function serialize_binary(session::Session, data)
    return serialize_binary(session, SerializedMessage(session, data))
end

function deserialize_binary(bytes::AbstractVector{UInt8}, compression_enabled::Bool=false)
    if compression_enabled
        bytes = transcode(GzipDecompressor, bytes)
    end
    return MsgPack.unpack(bytes)
    # return decode_extension_and_addbits()
end

function deserialize(msg::SerializedMessage)
    MsgPack.unpack(msg.bytes)
end

function serialize_string(session::Session, @nospecialize(obj))
    binary = serialize_binary(session, obj)
    return Base64.base64encode(binary)
end

function deserialize_string(b64str::String)
    bytes = Base64.base64decode(b64str)
    return deserialize_binary(bytes)
end
