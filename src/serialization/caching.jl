struct SerializationContext
    # OrderedDict preserves insertion order, which ensures that dependencies (inner observables)
    # are serialized before their dependents (outer observables containing CacheKey references).
    # This is critical for static export where the JS side deserializes the cache dict
    # and needs to resolve CacheKey references during unpacking.
    message_cache::OrderedDict{String, Any}
    session::Session
end

"""
    CachedEntry(object, owners)

Value stored in `root.session_objects` for objects that have been
serialized to JS and cached for this connection. `owners` is the set of
session ids (root + any sub) that have registered the key.

Lifetime rule: the entry survives as long as `owners` (filtered to
sessions still present in the live tree via `get_session(root, id)`) is
non-empty. Sub-close decrements its id; root-close drops the whole
cache. The `filter` step makes this self-healing — if a session vanished
without a clean close, its dead id gets pruned and the entry can still
be reclaimed.

INVARIANT: every read or mutation of an entry's `owners` field happens
under `root.deletion_lock` (the same lock that gates all
`session_objects` access). Plain `Set` is fine because the lock is the
synchronization boundary; per-entry locking would just be overhead.
"""
mutable struct CachedEntry
    object::Any
    owners::Set{String}
end
CachedEntry(object) = CachedEntry(object, Set{String}())

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
        # If this session already tracks the key, nothing to do — we
        # already added our id to root's `owners` set the first time.
        if haskey(session.session_objects, key)
            return result
        end
        # Sub sessions keep a marker (value is meaningless — only the
        # presence of the key matters; `free()` iterates these to
        # decrement owner sets at close time).
        if session !== root
            session.session_objects[key] = nothing
        end
        if haskey(root.session_objects, key)
            # Root cache already holds this — just register `session.id`
            # as a new owner and tell JS via TrackingOnly. The JS side
            # already has the object in its global cache.
            entry = root.session_objects[key]::CachedEntry
            push!(entry.owners, session.id)
            send_to_js[key] = TrackingOnly(key)
        else
            # First time anyone in this connection cached this object.
            # IMPORTANT: call `create_cached_object` BEFORE inserting into
            # `root.session_objects`. The closure transitively invokes
            # `register_observable!`, which short-circuits when
            # `haskey(root.session_objects, key)` is already true — so if
            # we insert first, the JS-update listener never gets attached
            # and JS notifies silently fail to reach Julia.
            serialized = create_cached_object()
            root.session_objects[key] = CachedEntry(object, Set{String}((session.id,)))
            send_to_js[key] = serialized
        end
        return result
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
    entry = root.session_objects[key]::CachedEntry
    # Drop the closing sub from the owner set.
    delete!(entry.owners, sub.id)
    # Self-heal: prune any owners whose sessions no longer exist in the
    # live tree (covers crashes / dropped WS where `free` never ran).
    # This is the safety net that makes refcount-by-id robust.
    filter!(id -> get_session(root, id) !== nothing || id == root.id,
            entry.owners)
    # Backwards-compat: legacy Retain wrapping inside the entry's object
    # still means "never release until root closes".
    entry.object isa Retain && return
    if isempty(entry.owners)
        pop!(root.session_objects, key)
        if entry.object isa Observable
            remove_js_updates!(sub, entry.object)
        end
    end
end


function force_delete!(root::Session, key::String)
    if !haskey(root.session_objects, key)
        # This should uncover any fault in our caching logic!
        @warn("Deleting key that doesn't belong to any cached object")
        return nothing
    end
    entry = pop!(root.session_objects, key)::CachedEntry
    object = entry.object
    if object isa Retain
        object = object.value
    end
    if object isa Observable
        # unregister all listeners updating the session
        remove_js_updates!(root, object)
    end
end
