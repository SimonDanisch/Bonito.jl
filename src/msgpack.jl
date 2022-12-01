
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
function ByteVec(array::AbstractVector{T}) where T
    # copies abstract arrays, but leaves Vector{T} unchanged
    return ByteVec(convert(Vector{T}, array))
end

MsgPack.msgpack_type(::Type{<: AbstractVector{<: JSTypedNumber}}) = MsgPack.ExtensionType()

function MsgPack.to_msgpack(::MsgPack.ExtensionType, x::AbstractVector{T}) where T <: JSTypedNumber
    type = findfirst(isequal(T), JSTypedArrayEltypes) + 0x10
    return MsgPack.Extension(Int8(type), convert(Vector{T}, x))
end

MsgPack.msgpack_type(::Type{<: AbstractVector{Float16}}) = MsgPack.ExtensionType()

function MsgPack.to_msgpack(EXT::MsgPack.ExtensionType, x::AbstractVector{Float16})
    return MsgPack.to_msgpack(EXT, convert(Vector{Float32}, x))
end

const OBSERVABLE_TAG = Int8(100)
MsgPack.msgpack_type(::Type{<: SerializedObservable}) = MsgPack.ExtensionType()
function MsgPack.to_msgpack(::MsgPack.ExtensionType, x::SerializedObservable)
    return MsgPack.Extension(OBSERVABLE_TAG, pack([x.id, x.value]))
end

MsgPack.msgpack_type(::Type{<: Observable}) = MsgPack.ExtensionType()
function MsgPack.to_msgpack(::MsgPack.ExtensionType, x::Observable)
    return MsgPack.Extension(OBSERVABLE_TAG, pack([x.id, x[]]))
end

const ASSET_TAG = Int8(101)
MsgPack.msgpack_type(::Type{SerializedAsset}) = MsgPack.ExtensionType()
function MsgPack.to_msgpack(::MsgPack.ExtensionType, x::SerializedAsset)
    return MsgPack.Extension(ASSET_TAG, pack([x.es6module, x.url]))
end

const JSCODE_TAG = Int8(102)
MsgPack.msgpack_type(::Type{SerializedJSCode}) = MsgPack.ExtensionType()
function MsgPack.to_msgpack(::MsgPack.ExtensionType, x::SerializedJSCode)
    return MsgPack.Extension(JSCODE_TAG, pack([x.interpolated_objects, x.source, x.julia_file]))
end

const RETAIN_TAG = Int8(103)
MsgPack.msgpack_type(::Type{Retain}) = MsgPack.ExtensionType()
function MsgPack.to_msgpack(::MsgPack.ExtensionType, x::Retain)
    return MsgPack.Extension(RETAIN_TAG, pack(x.value))
end

const CACHE_KEY_TAG = Int8(104)
MsgPack.msgpack_type(::Type{CacheKey}) = MsgPack.ExtensionType()
function MsgPack.to_msgpack(::MsgPack.ExtensionType, x::CacheKey)
    return MsgPack.Extension(CACHE_KEY_TAG, pack(x.key))
end

const DOM_NODE_TAG = Int8(105)
MsgPack.msgpack_type(::Type{SerializedNode}) = MsgPack.ExtensionType()
function MsgPack.to_msgpack(::MsgPack.ExtensionType, x::SerializedNode)
    return MsgPack.Extension(DOM_NODE_TAG, pack([x.tag, x.children, x.attributes]))
end

const SESSION_CACHE_TAG = Int8(106)
MsgPack.msgpack_type(::Type{SessionCache}) = MsgPack.ExtensionType()
function MsgPack.to_msgpack(::MsgPack.ExtensionType, x::SessionCache)
    return MsgPack.Extension(SESSION_CACHE_TAG, pack([x.session_id, x.objects]))
end

const SERIALIZED_MESSAGE_TAG = Int8(107)
MsgPack.msgpack_type(::Type{SerializedMessage}) = MsgPack.ExtensionType()
function MsgPack.to_msgpack(::MsgPack.ExtensionType, x::SerializedMessage)
    return MsgPack.Extension(SERIALIZED_MESSAGE_TAG, x.bytes)
end

# The other side does the same (/frontend/common/MsgPack.js), and we decode it here:
function decode_extension_and_addbits(ext::MsgPack.Extension)
    if ext.type == 0x0d
        # the datetime type
        millisecs_since_1970_because_thats_how_computers_work = reinterpret(Int64, ext.data)[1]
        Dates.DateTime(1970) + Dates.Millisecond(millisecs_since_1970_because_thats_how_computers_work)
        # TODO? Dates.unix2datetime does exactly this ?? - DRAL
    else
        if OBSERVABLE_TAG == ext.type
            id_value = MsgPack.unpack(ext.data)
            return Observable(decode_extension_and_addbits(id_value[2]))
        elseif CACHE_KEY_TAG == ext.type
            key = MsgPack.unpack(ext.data)
            return CacheKey(key)
        elseif  RETAIN_TAG == ext.type
            value = MsgPack.unpack(ext.data)
            return Retain(decode_extension_and_addbits(value))
        else
            idx = Int(ext.type - 0x10)
            if checkbounds(Bool, JSTypedArrayEltypes, idx)
                ElType = JSTypedArrayEltypes[idx]
                return reinterpret(ElType, ext.data)
            else
                return ext
            end
        end
    end
end

function decode_extension_and_addbits(x::Dict)
    # we mutate the dictionary, that's fine in our use case and saves memory?
    for (k, v) in x
        x[k] = decode_extension_and_addbits(v)
    end
    x
end
decode_extension_and_addbits(x::Array) = map(decode_extension_and_addbits, x)

# We also convert everything (except the JS typed arrays) to 64 bit numbers, just to make it easier to work with.
decode_extension_and_addbits(x::T) where T <: Union{Signed,Unsigned} = Int64(x)
decode_extension_and_addbits(x::T) where T <: AbstractFloat = Float64(x)
decode_extension_and_addbits(x::Any) = x
