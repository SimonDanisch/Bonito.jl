include("types.jl")
include("msgpack.jl")
include("caching.jl")
include("protocol.jl")


function serialize_cached(session::Session, data)
    ctx = SerializationContext(session)
    message_data = serialize_cached(ctx, data)
    return [SessionCache(session, ctx.message_cache), message_data]
end

function SerializedMessage(session::Session, data)
    serialized = serialize_cached(session, data)
    bytes = MsgPack.pack(serialized)
    if session.compression_enabled
        bytes = transcode(GzipCompressor, bytes)
    end
    return SerializedMessage(bytes)
end

serialize_binary(session::Session, data) = SerializedMessage(session, data).bytes

function deserialize_binary(bytes::AbstractVector{UInt8})
    # message_msgpacked = transcode(GzipDecompressor, bytes)
    # return MsgPack.unpack(message_msgpacked)
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
