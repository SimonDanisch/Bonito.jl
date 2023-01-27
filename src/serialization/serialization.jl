include("types.jl")
include("msgpack.jl")
include("caching.jl")
include("protocol.jl")

function serialize_binary(session::Session, @nospecialize(obj))
    data = serialize_cached(session, obj)
    return MsgPack.pack(data)
end

function serialize_binary(session::Session, msg::SerializedMessage)
    return MsgPack.pack(msg)
end

function deserialize_binary(bytes::AbstractVector{UInt8})
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
