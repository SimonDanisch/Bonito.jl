include("types.jl")
include("msgpack.jl")
include("caching.jl")
include("protocol.jl")

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

function deserialize(msg::SerializedMessage)
    MsgPack.unpack(msg.bytes)
end
