
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
# 103 was RETAIN_TAG — removed in the cache-refcount refactor
const CACHE_KEY_TAG = Int8(104)
const DOM_NODE_TAG = Int8(105)
const SESSION_CACHE_TAG = Int8(106)
const SERIALIZED_MESSAGE_TAG = Int8(107)
const RAW_HTML_TAG = Int8(108)
const TRACKING_ONLY_TAG = Int8(109)

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

MsgPack.msgpack_type(::Type{CacheKey}) = MsgPack.ExtensionType()
function MsgPack.to_msgpack(::MsgPack.ExtensionType, x::CacheKey)
    return MsgPack.Extension(CACHE_KEY_TAG, pack(x.key))
end

MsgPack.msgpack_type(::Type{TrackingOnly}) = MsgPack.ExtensionType()
function MsgPack.to_msgpack(::MsgPack.ExtensionType, x::TrackingOnly)
    return MsgPack.Extension(TRACKING_ONLY_TAG, pack(x.key))
end

MsgPack.msgpack_type(::Type{SerializedNode}) = MsgPack.ExtensionType()
function MsgPack.to_msgpack(::MsgPack.ExtensionType, x::SerializedNode)
    return MsgPack.Extension(DOM_NODE_TAG, pack([x.tag, x.children, x.attributes]))
end

MsgPack.msgpack_type(::Type{Base.HTML{String}}) = MsgPack.ExtensionType()
function MsgPack.to_msgpack(::MsgPack.ExtensionType, x::Base.HTML)
    return MsgPack.Extension(RAW_HTML_TAG, pack(x.content))
end

# ── SessionIO forwarding + pack_extension! API ─────────────────────────────
#
# SessionIO is defined in types.jl. Here we wire it up as a writable IO that
# routes through a stack of reusable scratch buffers — so nested msgpack
# Extension payloads can be packed without allocating an IOBuffer per layer.

@inline current_buffer(s::SessionIO) =
    s.depth == 0 ? (s.output::IOBuffer) : @inbounds s.scratches[s.depth]

# Only override the two write methods that the rest of Julia's IO machinery
# funnels through: a direct byte write and the bulk unsafe_write. Real / String /
# Array writes in `Base` all reduce to one of these, so we don't have to
# enumerate them (and avoid ambiguity with Base's specialized `write(::IO, ::Int8)`
# etc.).
@inline Base.write(s::SessionIO, x::UInt8) = write(current_buffer(s), x)
@inline Base.unsafe_write(s::SessionIO, p::Ptr{UInt8}, n::UInt) = unsafe_write(current_buffer(s), p, n)
# Typed-array fast paths in this module's `pack_type` overrides (line 36 below)
# call `real_unsafe_write` directly on the IO; forward to the active buffer.
@inline real_unsafe_write(s::SessionIO, data::Array) = real_unsafe_write(current_buffer(s), data)

# Hook MsgPack's fast-path `write_be(::IOBuffer, ::Primitive)` so primitive
# writes through SessionIO still hit the SROA'd direct-buffer store, not the
# generic `write(io, hton(x))` fallback that allocates a Ref.
@inline MsgPack.write_be(s::SessionIO, x::MsgPack.Primitive) =
    MsgPack.write_be(current_buffer(s), x)

@inline function reset_for_reuse!(io::IOBuffer)
    # No public IOBuffer API resets size+ptr without dropping the backing
    # Memory's capacity (`take!` empties it, `truncate(io,0)` resizes it to 0).
    # We need to keep the capacity so subsequent messages don't re-grow.
    io.size = 0
    io.ptr  = 1
    return nothing
end

"""
    pack_extension!(f, s::SessionIO, tag::Int8)

Open a nested-extension scope: pushes a fresh scratch IOBuffer onto `s`'s stack,
runs `f()` (which writes the payload via `pack(s, ...)` / `write(s, ...)`), then
emits `[ext_header(tag, payload_size), payload_bytes]` to the layer below.

No try/finally — if `f` errors the next top-level pack call will reset the
SessionIO from a clean state (see `pack_type(::IOBuffer, ::SerializedMessage)`).
"""
function pack_extension!(f, s::SessionIO, tag::Int8)
    s.depth += 1
    if s.depth > length(s.scratches)
        # Grow scratch stack lazily. Sizehint matches typical inner-extension
        # payloads (cache and data sections of a small Bonito message).
        push!(s.scratches, IOBuffer(UInt8[]; sizehint=512, append=true))
    end
    scratch = @inbounds s.scratches[s.depth]
    f()
    payload_size = scratch.size
    # Pop FIRST so write_extension_header writes into the parent layer.
    s.depth -= 1
    parent = current_buffer(s)
    MsgPack.write_extension_header(parent, payload_size, tag)
    if payload_size > 0
        GC.@preserve scratch unsafe_write(parent, pointer(scratch.data), UInt(payload_size))
    end
    reset_for_reuse!(scratch)
    return nothing
end

# ── SessionCache / SerializedMessage stream-pack fast paths ────────────────

MsgPack.msgpack_type(::Type{SessionCache}) = MsgPack.ExtensionType()

# Wire format: Extension(SESSION_CACHE_TAG, msgpack array of 3 elements
# [session_id, session_type, Extension(18){packed_objects}]). JS extracts
# session_id / session_type first to set up its decode context before
# materializing the observables (see js_dependencies/Protocol.js
# `register_ext(SESSION_CACHE_TAG, ...)`).
function MsgPack.pack_type(io::SessionIO, ::MsgPack.ExtensionType, x::SessionCache)
    pack_extension!(io, SESSION_CACHE_TAG) do
        write(io, MsgPack.magic_byte_min(MsgPack.ArrayFixFormat) | UInt8(3))  # fix-array(3)
        pack(io, x.session_id)
        pack(io, x.session_type)
        pack_extension!(io, Int8(18)) do  # objects, wrapped to match Bonito's Vector{UInt8} ext
            pack(io, collect(values(x.objects)))
        end
    end
    return nothing
end

# Fallback: pack(::IOBuffer, ::SessionCache) — called when tests pack a
# SessionCache standalone (no enclosing Session). Wrap the io in a one-shot
# SessionIO so the stream-pack logic above applies uniformly.
function MsgPack.pack_type(io, ::MsgPack.ExtensionType, x::SessionCache)
    s = SessionIO()
    s.output = io
    MsgPack.pack_type(s, MsgPack.ExtensionType(), x)
end

MsgPack.msgpack_type(::Type{BinaryMessage}) = MsgPack.ExtensionType()
function MsgPack.to_msgpack(::MsgPack.ExtensionType, x::BinaryMessage)
    return MsgPack.Extension(SERIALIZED_MESSAGE_TAG, x.bytes)
end

MsgPack.msgpack_type(::Type{SerializedMessage}) = MsgPack.ExtensionType()

# Wire format: Extension(SERIALIZED_MESSAGE_TAG, msgpack array of 4 elements
# [session_id, session_status, Extension(18){packed_cache}, Extension(18){packed_data}]).
# JS pulls session info first to set up its decode context, then unpacks cache
# (so observables register) before data.

# Shared payload body. Assumes the caller has already opened the outer
# SERIALIZED_MESSAGE_TAG extension scope; we just write the 4-element array.
function write_serialized_message_payload!(io::SessionIO, x::SerializedMessage)
    write(io, MsgPack.magic_byte_min(MsgPack.ArrayFixFormat) | UInt8(4))  # fix-array(4)
    pack(io, x.cache.session_id)
    pack(io, x.cache.session_type)
    pack_extension!(io, Int8(18)) do  # cache, wrapped to match Bonito's Vector{UInt8} ext
        pack(io, x.cache)
    end
    pack_extension!(io, Int8(18)) do  # data, same wrapping
        pack(io, x.data)
    end
    return nothing
end

# Top-level entry: `io` is whatever MsgPack.pack(sm) handed us (always an
# IOBuffer in Bonito's hot path). Bootstrap the session's reusable SessionIO,
# lock for the duration, then defer to the shared body.
function MsgPack.pack_type(io::IOBuffer, ::MsgPack.ExtensionType, x::SerializedMessage)
    s = x.pack_io
    lock(s.lock) do
        s.output = io
        s.depth = 0
        for scratch in s.scratches
            reset_for_reuse!(scratch)
        end
        pack_extension!(s, SERIALIZED_MESSAGE_TAG) do
            write_serialized_message_payload!(s, x)
        end
    end
    return nothing
end

# Nested entry: `io` is a SessionIO already mid-stream (e.g. a Vector of
# SerializedMessages was packed by a containing pack_type). Reuse that
# SessionIO directly — its lock is already held by the top-level caller, and
# x.pack_io may be a different session's scratch which we don't want to touch.
function MsgPack.pack_type(io::SessionIO, ::MsgPack.ExtensionType, x::SerializedMessage)
    pack_extension!(io, SERIALIZED_MESSAGE_TAG) do
        write_serialized_message_payload!(io, x)
    end
    return nothing
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
