struct SerializationContext
    # OrderedDict preserves insertion order, which ensures that dependencies (inner observables)
    # are serialized before their dependents (outer observables containing CacheKey references).
    # This is critical for static export where the JS side deserializes the cache dict
    # and needs to resolve CacheKey references during unpacking.
    message_cache::OrderedDict{String, Any}
    session::Session
end

function SerializationContext(session::Session)
    return SerializationContext(OrderedDict{String,Any}(), session)
end

object_identity(retain::Retain) = object_identity(retain.value)
object_identity(obs::Observable) = obs.id
object_identity(obj::Any) = string(hash(obj))


function register_observable!(session::Session, obs::Observable)
    # Always register with root session!
    # TODO, this may be a problem for Observable{Observable}
    # since the updates are serialized via the root session then, which means they will never get freed
    root = root_session(session)
    # Only register one time
    if !haskey(root.session_objects, obs.id)
        updater = JSUpdateObservable(session, obs.id)
        # Don't deregister on root / or session close
        # The updaters callbacks are freed manually in delete_cached!`
        on(updater, obs)
    end
    return
end


function serialize_cached(context::SerializationContext, retain::Retain)
    return add_cached!(context.session, context.message_cache, retain) do
        obs = retain.value
        register_observable!(context.session, obs)
        return Retain(SerializedObservable(obs.id, serialize_cached(context, obs[])))
    end
end

function serialize_cached(context::SerializationContext, obs::Observable)
    return add_cached!(context.session, context.message_cache, obs) do
        register_observable!(context.session, obs)
        return SerializedObservable(obs.id, serialize_cached(context, obs[]))
    end
end

function serialize_cached(context::SerializationContext, js::JSCode)
    jscontext = JSSourceContext(context.session)
    # Print code while collecting all interpolated objects in an IdDict
    code = sprint() do io
        print_js_code(io, js, jscontext)
    end
    # reverse lookup and serialize elements
    interpolated_objects = Dict{String,Any}(v => serialize_cached(context, k) for (k, v) in jscontext.objects)
    return SerializedJSCode(
        interpolated_objects,
        code,
        js.file
    )
end

function serialize_cached(context::SerializationContext, node::Node{Hyperscript.HTMLSVG})
    return SerializedNode(context.session, node)
end

function serialize_cached(context::SerializationContext, lu::LargeUpdate)
    return serialize_cached(context, lu.data)
end


serialize_cached(::SerializationContext, @nospecialize(obj)) = obj
serialize_cached(::SerializationContext, native::MSGPACK_NATIVE_TYPES) = native
serialize_cached(::SerializationContext, native::AbstractArray{<:Number}) = native

function serialize_cached(context::SerializationContext, x::Union{AbstractArray, Tuple})
    result = Vector{Any}(undef, length(x))
    @inbounds for (i, elem) in enumerate(x)
        result[i] = serialize_cached(context, elem)
    end
    return result
end

function serialize_cached(context::SerializationContext, dict::AbstractDict)
    result = Dict{String, Any}()
    for (k, v) in dict
        result[string(k)] = serialize_cached(context, v)
    end
    return result
end

"""
    add_cached!(create_cached_object::Function, session::Session, message_cache::AbstractDict{String, Any}, key::String)

Checks if key is already cached by the session or it's root session (we skip any child session between root -> this session).
If not cached already, we call `create_cached_object` to create a serialized form of the object corresponding to `key` and cache it.
We return nothing if already cached, or the serialized object if not cached.
We also handle the part of adding things to the message_cache from the serialization context.
"""
function add_cached!(create_cached_object::Function, session::Session, send_to_js::AbstractDict{String, Any}, @nospecialize(object))::CacheKey
    root = root_session(session)
    lock(root.deletion_lock) do
        key = object_identity(object)::String
        result = CacheKey(key)
        # If already in session, there's nothing we need to do, since we've done the work the first time we added the object
        if haskey(session.session_objects, key)
            return result
        end
        # Now, we have two code paths, depending on whether we have a child session or a root session
        # we are root, so we simply cache the object (we already checked it's not cached yet)
        if root === session
            send_to_js[key] = create_cached_object()
            session.session_objects[key] = object
            return result
        else
            # This session is a child session.
            # Now we need to figure out if the root session has the object cached already
            # The root session has our object cached already.
            session.session_objects[key] = nothing # session needs to reference this to "own" it
            if haskey(root.session_objects, key)
                # in this case, we just add the key to send to js, so that the JS side can associate the object with this session
                send_to_js[key] = TrackingOnly(key)
                return result
            end
            # Nobody has the object cached,
            # so we add this session as the owner, but also add it to the root session
            send_to_js[key] = create_cached_object()
            root.session_objects[key] = object
            return result
        end
    end
end

function child_has_reference(child::Session, key)
    haskey(child.session_objects, key) && return true
    return any(((id, s),)-> child_has_reference(s, key), child.children)
end

function remove_js_updates!(session::Session, observable::Observable)
    filter!(observable.listeners) do (prio, f)
        !(f isa JSUpdateObservable && f.session === session)
    end
end

function delete_cached!(root::Session, sub::Session, key::String)
    if !haskey(root.session_objects, key)
        # This should uncover any fault in our caching logic!
        @warn("Deleting key that doesn't belong to any cached object")
        return
    end
    # We only free Retain, when the root session is closing!
    root.session_objects[key] isa Retain && return
    # We don't do reference counting, but we check if any child still holds a reference to the object we want to delete
    has_ref = any(((id, s),)-> child_has_reference(s, key), root.children)
    if !has_ref
        # So only delete it if nobody has it anymore!
        object = pop!(root.session_objects, key)
        if object isa Observable
            # unregister all listeners updating the session
            remove_js_updates!(sub, object)
        end
    end
end


function force_delete!(root::Session, key::String)
    if !haskey(root.session_objects, key)
        # This should uncover any fault in our caching logic!
        @warn("Deleting key that doesn't belong to any cached object")
        return nothing
    end
    # We only free Retain, when the root session is closing!
    object = pop!(root.session_objects, key)
    if object isa Retain
        object = object.value
    end
    if object isa Observable
        # unregister all listeners updating the session
        remove_js_updates!(root, object)
    end
end
