include("types.jl")
include("msgpack.jl")
include("caching.jl")
include("protocol.jl")

function serialize_cached(session::Session, data)
    return lock(root_session(session).deletion_lock) do
        ctx = SerializationContext(session)
        message_data = serialize_cached(ctx, data)
        return SerializedMessage(SessionCache(session, ctx.message_cache), message_data)
    end
end

function BinaryMessage(session::Session, data)
    sm = serialize_cached(session, data)
    bytes = MsgPack.pack([sm.cache, sm.data])
    return BinaryMessage(bytes)
end

function serialize_binary(session::Session, msg::BinaryMessage)
    bytes = msg.bytes
    if session.compression_enabled
        bytes = transcode(GzipCompressor, bytes)
    end
    return bytes
end

function serialize_binary(session::Session, data)
    return serialize_binary(session, BinaryMessage(session, data))
end

function deserialize_binary(bytes::AbstractVector{UInt8}, compression_enabled::Bool=false)
    if compression_enabled
        bytes = transcode(GzipDecompressor, bytes)
    end
    return MsgPack.unpack(bytes)
    # return decode_extension_and_addbits()
end

function deserialize(msg::BinaryMessage)
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
