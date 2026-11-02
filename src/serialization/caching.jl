struct SerializationContext
    # Decode nested objects before the objects that reference them.
    message_cache::OrderedDict{String, Any}
    session::Session
end

# The root keeps each object until its last owning session closes.
# Access to the owners is protected by root.deletion_lock.
struct CachedEntry
    object::Any
    owners::Set{Session}
end

function SerializationContext(session::Session)
    return SerializationContext(OrderedDict{String,Any}(), session)
end

object_identity(obs::Observable) = obs.id
object_identity(obj::Any) = string(hash(obj))

# Observable ids are process-local. Proxy prefixes disambiguate them in the
# browser's shared cache and route updates to the worker. Normal sessions keep
# obs.id; asset identities remain shared across sessions.
function cache_key(session::Session, obs::Observable)
    prefix = id_prefix(connection(session))
    return isempty(prefix) ? obs.id : string(prefix, "/", obs.id)
end
cache_key(session::Session, @nospecialize(obj)) = object_identity(obj)


function register_observable!(session::Session, obs::Observable)
    # The updater lives until the last owner closes, not just the first sub.
    root = root_session(session)
    key = cache_key(session, obs)
    lock(root.deletion_lock) do
        if !haskey(root.session_objects, key)
            updater = JSUpdateObservable(root, key)
            # The last owner removes this updater through delete_cached!.
            on(updater, obs)
        end
    end
    return
end


function serialize_cached(context::SerializationContext, obs::Observable)
    return add_cached!(context.session, context.message_cache, obs) do
        register_observable!(context.session, obs)
        return SerializedObservable(cache_key(context.session, obs), serialize_cached(context, obs[]))
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

# Fast path for the common Observable-update shape — `Dict{String,Any}` whose
# values are all msgpack primitives (Number/String/Bool/Nothing). No keys to
# stringify, no values to recurse into, nothing to register in the cache, so
# we can hand the input dict straight through to MsgPack.pack and skip the
# rebuild that the generic AbstractDict method does. JSUpdateObservable
# already builds messages in this shape, so every Observable update hits this
# branch.
@inline is_msgpack_primitive(::Number) = true
@inline is_msgpack_primitive(::AbstractString) = true
@inline is_msgpack_primitive(::Bool) = true
@inline is_msgpack_primitive(::Nothing) = true
@inline is_msgpack_primitive(@nospecialize(_)) = false

function serialize_cached(context::SerializationContext, dict::Dict{String,Any})
    @inbounds for v in values(dict)
        is_msgpack_primitive(v) || return Dict{String,Any}(k => serialize_cached(context, v) for (k, v) in dict)
    end
    return dict
end

function add_cached!(create_cached_object::Function, session::Session, send_to_js::AbstractDict{String, Any}, @nospecialize(object))::CacheKey
    root = root_session(session)
    lock(root.deletion_lock) do
        key = cache_key(session, object)::String
        result = CacheKey(key)
        # The root stores every entry, including ones it does not own itself.
        # Subsessions store only their own keys.
        if session === root
            entry = get(root.session_objects, key, nothing)
            if entry isa CachedEntry && root in entry.owners
                return result
            end
        elseif haskey(session.session_objects, key)
            return result
        end
        if session !== root
            session.session_objects[key] = nothing
        end
        if haskey(root.session_objects, key)
            entry = root.session_objects[key]::CachedEntry
            # A detached subsession may load after every other owner has closed.
            # Only messages on the live, ordered connection can reuse a copy.
            ordered = sends_in_order(session)
            reuse = ordered && any(sends_in_order, entry.owners)
            send_to_js[key] = reuse ? TrackingOnly(key) : create_cached_object()
            push!(entry.owners, session)
        else
            # Registration must precede insertion: register_observable! skips
            # entries already present in the root cache.
            serialized = create_cached_object()
            entry = CachedEntry(object, Set{Session}((session,)))
            root.session_objects[key] = entry
            send_to_js[key] = serialized
        end
        return result
    end
end

# Live messages can reuse earlier values only when no queued message can be
# overtaken. Deferred HTML initialization has not established that order yet.
sends_in_order(session::Session) = sends_in_order(connection(session), session)
function sends_in_order(::FrontendConnection, session::Session)
    return isready(session; throw=false) && isempty(session.message_queue)
end
# A static page reads the root's payload before any sub's, and frees nothing.
sends_in_order(::NoConnection, session::Session) = isroot(session)

# SessionCache already carries browser ownership; include pending owners before
# an update or release can leave their delayed initialization without a copy.
function register_owners!(cache::SessionCache, key::String, entry::CachedEntry, value)
    for owner in entry.owners
        sends_in_order(owner) && continue
        owned = get!(cache.objects, owner.id) do
            SessionCache(owner, OrderedDict{String,Any}())
        end
        owned.objects[key] = value
    end
    return cache
end

# Remove only the updater owned by this session tree.
function remove_js_updates!(key::String, observable::Observable, session::Session)
    root = root_session(session)
    lock(root.deletion_lock) do
        filter!(observable.listeners) do (prio, f)
            !(f isa JSUpdateObservable && f.id == key && f.session === root)
        end
    end
end

function delete_cached!(root::Session, sub::Session, key::String)
    if !haskey(root.session_objects, key)
        # This should uncover any fault in our caching logic!
        @warn("Deleting key that doesn't belong to any cached object")
        return
    end
    entry = root.session_objects[key]::CachedEntry
    delete!(entry.owners, sub)
    filter!(owner -> !isclosed(owner), entry.owners)
    if isempty(entry.owners)
        pop!(root.session_objects, key)
        if entry.object isa Observable
            remove_js_updates!(key, entry.object, root)
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
    if entry.object isa Observable
        remove_js_updates!(key, entry.object, root)
    end
end

