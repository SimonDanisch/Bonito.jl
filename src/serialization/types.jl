struct SerializedObservable
    id::String
    value::Any
end

struct CacheKey
    key::String
end

struct Retain
    value::Union{Observable, SerializedObservable} # For now, restricted to observable!
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
