"""
Context to replace identical objects (by pointer)
"""
struct SerializationContext
    global_objects::Union{Nothing, Dict{String, WeakRef}}
    serialized_objects::Union{Nothing, Dict{String, Any}}
    interpolated::Union{Nothing, Vector{Any}}
    duplicates::Set{String}
end

function SerializationContext(global_objects=nothing)
    return SerializationContext(global_objects, Dict{String, Any}(), [], Set{String}())
end
function SerializationContext(serialized_objects::Nothing, interpolated=nothing)
    return SerializationContext(nothing, serialized_objects, interpolated, Set{String}())
end
function pointer_identity(@nospecialize(x::Union{AbstractString, AbstractArray}))
    # hate on strings - but JS loves this shit
    return string(UInt64(pointer(x)))
end

function pointer_identity(@nospecialize(x))
    # hate on strings - but JS loves this shit
    return string(UInt64(pointer_from_objref(x)))
end

function add_to_cache!(context::SerializationContext, @nospecialize(object))
    isnothing(context.serialized_objects) && return # we don't want to cache ANYTHING
    isbits(object) && return # dont cache value types
    Base.summarysize(object) / 10^6 < 0.01 && return # only cache largish objects
    ref = pointer_identity(object)
    # if object is in global cache, insert it locally
    if !isnothing(context.global_objects) && haskey(context.global_objects, ref)
        @info("$(typeof(object)) with $(ref) already in global cache")
        # We can assume that this is already globally available
        # so no need to push it to duplicates!
        return ref
    end
    # we return the ref, since we have a duplicate here!
    if haskey(context.serialized_objects, ref)
        push!(context.duplicates, ref)
        return ref
    end
    # else, we just add it to the cache and do nothing for now!
    context.serialized_objects[ref] = object
    return
end

"""
    update_cache!(session::Session, objects::Dict{String, Any})
Updates the sessions object cache with new objects, and removes all GC'd objects
"""
function update_cache!(session::Session, objects::Dict{String, Any}, duplicates::Set{String})
    to_register = Dict{String, Any}()
    to_remove = String[]
    uoc = session.unique_object_cache
    duplicate_ser_context = SerializationContext(nothing, nothing)
    for k in duplicates
        o = objects[k]
        # handle expired WeakRefs + non existing keys in one go:
        val = get(uoc, k, WeakRef())
        if isnothing(val.value)
            to_register[k] = serialize_js(duplicate_ser_context, o)
            uoc[k] = WeakRef(o)
        end
    end

    for (k, o) in uoc
        if isnothing(o.value)
            push!(to_remove, k)
        end
    end

    return Dict(
        "to_register" => to_register,
        "to_remove" => to_remove,
    )
end

function serialize_binary(session::Session, @nospecialize(obj))
    context = SerializationContext(session.unique_object_cache)
    data = serialize_js(context, obj) # apply custom, overloadable transformation
    if !isempty(context.duplicates)
        @info("WE DO HAVE DUPLICATES!")
        message = update_cache!(session, context.serialized_objects, context.duplicates)
        @info("Duplicates: $(keys(message["to_register"]))")
        data = Dict(
            "update_cache" => message,
            "data" => data
        )
    end
    bytes = MsgPack.pack(data)
    @info(Base.format_bytes(sizeof(bytes)))
    return transcode(GzipCompressor, bytes)
end

function js_type(type::String, @nospecialize(x))
    return Dict(
        "__javascript_type__" => type,
        "payload" => x
    )
end

serialize_js(context::SerializationContext, @nospecialize(x)) = x

"""
Will insert julia values by value into e.g. js
```Julia
js"console.log(\$(by_value(observable)))"
--> {id: "xxx", value: the_value}
js"console.log(\$(observable))"
--> "xxx" # will be just the id to reference the observable
```
"""
function by_value(x::Observable)
    obs_val = Dict(:id=>x.id, :value=> x[])
    js_type("Observable", obs_val)
end

by_value(@nospecialize(x)) = x

function by_value(node::Hyperscript.Node{Hyperscript.HTMLSVG})
    return [
        :tag => getfield(node, :tag),
        :children => by_value.(getfield(node, :children)),
        getfield(node, :attrs)...
    ]
end

function ref_or(or_callback, context::SerializationContext, @nospecialize(x))
    ref = add_to_cache!(context, x)
    if isnothing(ref)
        return or_callback()
    else
        return js_type("Reference", ref)
    end
end

serialize_js(context::SerializationContext, x::Observable) = string(x.id)

function serialize_js(context::SerializationContext, node::Node)
    return js_type("DomNode", uuid(node))
end

function serialize_js(context::SerializationContext, x::Vector{T}) where {T<:Number}
    return ref_or(context, x) do
        return js_type("typed_vector", x)
    end
end

function serialize_js(context::SerializationContext, x::Union{AbstractArray, Tuple})
    return ref_or(context, x) do
        return map(x-> serialize_js(context, x), x)
    end
end

function serialize_js(context::SerializationContext, dict::AbstractDict)
    return ref_or(context, dict) do
        result = Dict()
        for (k, v) in dict
            result[k] = serialize_js(context, v)
        end
        return result
    end
end

serialize_js(context::SerializationContext, jss::JSString) = jss.source

function serialize_js(context::SerializationContext, jsc::Union{JSCode, JSString})
    isnothing(context.interpolated) || empty!(context.interpolated)
    js_string = sprint(io-> print_js_code(io, jsc, context))
    data = Dict("source" => js_string, "context" => copy(context.interpolated))
    return js_type("JSCode", data)
end

function serialize_js(context::SerializationContext, asset::Asset)
    return url(asset, session.url_serializer)
end

# MsgPack doesn't natively support Float16
MsgPack.msgpack_type(::Type{Float16}) = MsgPack.FloatType()
MsgPack.to_msgpack(::MsgPack.FloatType, x::Float16) = Float32(x)
