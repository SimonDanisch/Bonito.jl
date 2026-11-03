"""
Context to replace identical objects (by pointer)
"""
struct SerializationContext
    global_objects::Union{Nothing, Dict{String, WeakRef}}
    serialized_objects::Union{Nothing, Dict{String, Any}}
    interpolated::Union{Nothing, Vector{Any}}
    duplicates::Set{String}
    url_serializer::UrlSerializer
end

function SerializationContext(global_objects; url_serializer=UrlSerializer())
    return SerializationContext(global_objects, Dict{String, Any}(), [], Set{String}(), url_serializer)
end

function SerializationContext(serialized_objects::Nothing, interpolated=nothing; url_serializer=UrlSerializer())
    return SerializationContext(nothing, serialized_objects, interpolated, Set{String}(), url_serializer)
end

function pointer_identity(@nospecialize(x::Union{AbstractString, AbstractArray}))
    # hate on strings - but JS loves this shit
    return string(UInt64(pointer(x)))
end

function pointer_identity(@nospecialize(x))
    # hate on strings - but JS loves this shit
    return string(UInt64(pointer_from_objref(x)))
end

should_cache(@nospecialize(x)) = false

# For now, we only cache arrays bigger 0.01mb
# Which makes a huge impact already for WGLMakie

const CACHE_DUPLIACTES = Ref(true)

function should_cache(x::Array)
    return CACHE_DUPLIACTES[] && sizeof(x) / 10^6 > 0.01
end

function add_to_cache!(context::SerializationContext, @nospecialize(object))
    isnothing(context.serialized_objects) && return # we don't want to cache ANYTHING
    should_cache(object) || return # only cache values we can cache!
    ref = pointer_identity(object)
    # if object is in global cache, insert it locally
    if !isnothing(context.global_objects) && haskey(context.global_objects, ref)
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
    duplicate_ser_context = SerializationContext(nothing; url_serializer=session.url_serializer)
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

function update_cached_value!(session::Session, object)
    # If we cache while sending the message to update the object
    # it will just send a reference to the already cached value! :D
    ctx = SerializationContext(nothing)
    ref = JSServe.pointer_identity(object)
    message = Dict(
        :dont_serialize => true,
        :update_cache => Dict("to_remove" => [], "to_register" => Dict(ref => serialize_js(ctx, object)))
    )
    send(session, message)
end

function serialize_string(session::Session, @nospecialize(obj))
    binary = serialize_binary(session, obj)
    return Base64.base64encode(binary)
end

function serialize_binary(session::Session, @nospecialize(obj))
    data = obj
    # We need a way to not serialize messages, e.g. in `update_cached_value`
    if !get(obj, :dont_serialize, false)
        context = SerializationContext(session.unique_object_cache)
        data = serialize_js(context, obj) # apply custom, overloadable transformation
        # If we found duplicates, store them to the cache!
        # or if some balue was gc'ed, we need to clean up the cache
        has_dups, refs_deleted = !isempty(context.duplicates), any(((key, ref),)-> isnothing(ref.value), session.unique_object_cache)
        if has_dups || refs_deleted
            message = update_cache!(session, context.serialized_objects, context.duplicates)
            # we store to the cache by modifying the original message
            # which will then be handled by the JS side
            data = Dict(
                "update_cache" => message,
                "data" => data
            )
        end
    end
    return transcode(GzipCompressor, MsgPack.pack(data))
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
    obs_val = Dict(:id => x.id, :value => x[])
    js_type("Observable", obs_val)
end

by_value(@nospecialize(x)) = x

function by_value(node::Hyperscript.Node{Hyperscript.HTMLSVG})
    vals = Dict(
        "tag" => getfield(node, :tag),
        "children" => by_value.(getfield(node, :children))
    )
    merge!(vals, getfield(node, :attrs))
    return vals
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
        return js_type("TypedVector", x)
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
    ctx = isnothing(context.interpolated) ? [] : copy(context.interpolated)
    data = Dict("source" => js_string, "context" => ctx)
    return js_type("JSCode", data)
end

function serialize_js(context::SerializationContext, asset::Asset)
    return url(asset, context.url_serializer)
end

# MsgPack doesn't natively support Float16
MsgPack.msgpack_type(::Type{Float16}) = MsgPack.FloatType()
MsgPack.to_msgpack(::MsgPack.FloatType, x::Float16) = Float32(x)
