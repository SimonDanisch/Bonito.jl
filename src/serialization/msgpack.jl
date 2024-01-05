
# MsgPack doesn't natively support Float16
MsgPack.msgpack_type(::Type{Float16}) = MsgPack.FloatType()
MsgPack.to_msgpack(::MsgPack.FloatType, x::Float16) = Float32(x)


MsgPack.msgpack_type(::Type{<: AbstractVector{<: JSTypedNumber}}) = MsgPack.ExtensionType()

function real_unsafe_write(io::IOBuffer, data::Array{T}) where T
    @assert isbitstype(T)
    nbytes = sizeof(data)
    Base.ensureroom(io, nbytes)
    ptr = (io.append ? io.size + 1 : io.ptr)
    written = Int(min(nbytes, Int(length(io.data))::Int - ptr + 1))
    GC.@preserve data begin
        Base.unsafe_copyto!(pointer(io.data, ptr), Ptr{UInt8}(pointer(data)), nbytes)
    end
    io.size = max(io.size, ptr - 1 + written)
    if !io.append
        io.ptr += written
    end
    return written
end

convert_for_write(x::Array) = x
convert_for_write(x::Base.ReinterpretArray) = x.parent
convert_for_write(x::AbstractArray) = collect(x)
convert_for_write(x::AbstractArray{Float16,N}) where {N} = convert(Array{Float32,N}, x)
convert_for_write(x::Array{Float16,N}) where {N} = convert(Array{Float32,N}, x)

array_tag(::Type{<: Float16}) = array_tag(Float32)

for (IDX, T) in enumerate(JSTypedArrayEltypes)
    @eval begin
        array_tag(::Type{$T}) = $(Int8(IDX + 0x10))
        function MsgPack.pack_type(io, ::MsgPack.ExtensionType, x::AbstractVector{$T})
            type = $(Int8(IDX + 0x10))
            array = convert_for_write(x)::Vector
            MsgPack.write_extension_header(io, sizeof(array), type)
            real_unsafe_write(io, array)
        end
    end
end

MsgPack.msgpack_type(::Type{<: AbstractVector{Float16}}) = MsgPack.ExtensionType()

function MsgPack.pack_type(io, ext::MsgPack.ExtensionType, x::AbstractVector{Float16})
    return MsgPack.pack_type(io, ext, convert(Vector{Float32}, x))
end

const ARRAY_TAG = Int8(99)
MsgPack.msgpack_type(::Type{<: AbstractArray{<: Union{Float16, JSTypedNumber}}}) = MsgPack.ExtensionType()

_eltype(x) = eltype(x) == Float16 ? Float32 : Float16


function MsgPack.pack_type(io, ::MsgPack.ExtensionType, x::AbstractArray{<:Union{Float16,JSTypedNumber}})
    array = convert_for_write(x)
    dims = pack(UInt32[size(x)...])
    f = MsgPack.ArrayFixFormat(MsgPack.magic_byte_min(MsgPack.ArrayFixFormat) | UInt8(2))
    tagtype = array_tag(eltype(x))
    # Size of the final binary array we attach to the extension
    nbytes = sizeof(f.byte) + sizeof(dims) + MsgPack.ext_header_size(sizeof(array)) + sizeof(array)
    MsgPack.write_extension_header(io, nbytes, ARRAY_TAG)
    write(io, f.byte)
    real_unsafe_write(io, dims)
    MsgPack.write_extension_header(io, sizeof(array), tagtype)
    real_unsafe_write(io, array)
end

const OBSERVABLE_TAG = Int8(101)
const JSCODE_TAG = Int8(102)
const RETAIN_TAG = Int8(103)
const CACHE_KEY_TAG = Int8(104)
const DOM_NODE_TAG = Int8(105)
const SESSION_CACHE_TAG = Int8(106)
const SERIALIZED_MESSAGE_TAG = Int8(107)
const RAW_HTML_TAG = Int8(108)

MsgPack.msgpack_type(::Type{<: SerializedObservable}) = MsgPack.ExtensionType()

function MsgPack.to_msgpack(::MsgPack.ExtensionType, x::SerializedObservable)
    return MsgPack.Extension(OBSERVABLE_TAG, pack([x.id, x.value]))
end

MsgPack.msgpack_type(::Type{<: Observable}) = MsgPack.ExtensionType()
function MsgPack.to_msgpack(::MsgPack.ExtensionType, x::Observable)
    return MsgPack.Extension(OBSERVABLE_TAG, pack([x.id, x[]]))
end

MsgPack.msgpack_type(::Type{SerializedJSCode}) = MsgPack.ExtensionType()
function MsgPack.to_msgpack(::MsgPack.ExtensionType, x::SerializedJSCode)
    return MsgPack.Extension(JSCODE_TAG, pack([x.interpolated_objects, x.source, x.julia_file]))
end

MsgPack.msgpack_type(::Type{Retain}) = MsgPack.ExtensionType()
function MsgPack.to_msgpack(::MsgPack.ExtensionType, x::Retain)
    return MsgPack.Extension(RETAIN_TAG, pack(x.value))
end

MsgPack.msgpack_type(::Type{CacheKey}) = MsgPack.ExtensionType()
function MsgPack.to_msgpack(::MsgPack.ExtensionType, x::CacheKey)
    return MsgPack.Extension(CACHE_KEY_TAG, pack(x.key))
end

MsgPack.msgpack_type(::Type{SerializedNode}) = MsgPack.ExtensionType()
function MsgPack.to_msgpack(::MsgPack.ExtensionType, x::SerializedNode)
    return MsgPack.Extension(DOM_NODE_TAG, pack([x.tag, x.children, x.attributes]))
end

MsgPack.msgpack_type(::Type{Base.HTML{String}}) = MsgPack.ExtensionType()
function MsgPack.to_msgpack(::MsgPack.ExtensionType, x::Base.HTML)
    return MsgPack.Extension(RAW_HTML_TAG, pack(x.content))
end

MsgPack.msgpack_type(::Type{SessionCache}) = MsgPack.ExtensionType()
function MsgPack.to_msgpack(::MsgPack.ExtensionType, x::SessionCache)
    return MsgPack.Extension(SESSION_CACHE_TAG, pack([x.session_id, x.objects, x.session_type]))
end

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
        elseif RETAIN_TAG == ext.type
            value = MsgPack.unpack(ext.data)
            return Retain(decode_extension_and_addbits(value))
        elseif SESSION_CACHE_TAG == ext.type
            value = decode_extension_and_addbits(MsgPack.unpack(ext.data))
            return SessionCache(value...)
        elseif JSCODE_TAG == ext.type
            value = decode_extension_and_addbits(MsgPack.unpack(ext.data))
            # MsgPack.Extension(JSCODE_TAG, pack([x.interpolated_objects, x.source, x.julia_file]))
            return JSCode([JSString(value[2])], value[3])
        elseif DOM_NODE_TAG == ext.type
            tag, children, attributes = decode_extension_and_addbits(MsgPack.unpack(ext.data))
            return Hyperscript.Node{Hyperscript.HTMLSVG}(Hyperscript.DEFAULT_HTMLSVG_CONTEXT, tag, children, attributes)
        elseif ARRAY_TAG == ext.type
            data = MsgPack.unpack(ext.data)
            unpacked = decode_extension_and_addbits(data)
            return reshape(unpacked[2], map(Int, unpacked[1])...)
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
