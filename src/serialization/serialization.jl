include("types.jl")
include("msgpack.jl")
include("caching.jl")
include("protocol.jl")

function SerializedMessage(session::Session, message)
    ctx = SerializationContext(session)
    message_data = serialize_cached(ctx, message)
    bytes = MsgPack.pack([SessionCache(session, ctx.message_cache), message_data])
    if session.compression_enabled
        bytes = transcode(GzipCompressor, bytes)
    end
    return SerializedMessage(bytes)
end

function deserialize_binary(bytes::AbstractVector{UInt8})
    # message_msgpacked = transcode(GzipDecompressor, bytes)
    # return MsgPack.unpack(message_msgpacked)
    return MsgPack.unpack(bytes)
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
