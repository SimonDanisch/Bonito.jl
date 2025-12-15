struct SerializedObservable
    id::String
    value::Any
end

struct CacheKey
    key::String
end

"""
    TrackingOnly(key::String)

Represents a cache entry that only needs to be tracked in a session but already exists
in the global cache. When deserialized in JS, it self-registers the key to the session's
tracked objects without adding anything to the global cache.
"""
struct TrackingOnly
    key::String
end

struct Retain
    value::Union{Observable, SerializedObservable} # For now, restricted to observable!
end

function SessionCache(session::Session, objects::OrderedDict{String,Any})
    return SessionCache(
        session.id,
        objects,
        root_session(session) === session ? "root" : "sub",
    )
end

function SessionCache(session::Session, objects::AbstractDict{String,Any})
    # Convert to OrderedDict to preserve insertion order
    return SessionCache(session, OrderedDict{String,Any}(objects))
end

struct SerializedJSCode
    interpolated_objects::Dict{String, Any}
    source::String
    julia_file::String
end

# We want typed arrays to arrive as JS typed arrays
const JSTypedArrayEltypes = [Int8, UInt8, Int16, UInt16, Int32, UInt32, Float32, Float64]
const JSTypedNumber = Union{JSTypedArrayEltypes...}

const MSGPACK_NATIVE_TYPES = Union{
    CacheKey,
    Retain,
    SerializedJSCode,
    Observable,
    AbstractVector{<: JSTypedNumber}
}
