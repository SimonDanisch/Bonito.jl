struct SerializationContext
    # OrderedDict preserves insertion order, which ensures that dependencies (inner observables)
    # are serialized before their dependents (outer observables containing CacheKey references).
    # This is critical for static export where the JS side deserializes the cache dict
    # and needs to resolve CacheKey references during unpacking.
    message_cache::OrderedDict{String, Any}
    session::Session
    # Keys this message references bare although the page may read it late;
    # pinned for `session` in one go once serialized (`pin_on_page!`).
    pins::Vector{String}
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

`on_page` is the subset of `owners` whose reference the page has read, or
reads before anything serialized from now on. Only while it is non-empty may
a new owner send a bare `TrackingOnly`: an owner's copy can reach the page
much later than its message was sent. A sub rendered inside other HTML loads
its payload from an inline script, which runs only once its DOM is in the
document, and a hidden pane or a virtual list keeps it out for as long as it
likes. A queued message waits for its session to connect. For the same
reason, a bare reference that the page may read late is pinned on the page
right away (`pin_on_page!`): the owners whose copy it relies on may be freed
before then, and the page frees an object once no session it knows tracks it.

INVARIANT: every read or mutation of an entry's `owners` and `on_page`
happens under `root.deletion_lock` (the same lock that gates all
`session_objects` access). Plain `Set` is fine because the lock is the
synchronization boundary; per-entry locking would just be overhead.
"""
mutable struct CachedEntry
    object::Any
    owners::Set{String}
    on_page::Set{String}
end
CachedEntry(object, owners::Set{String}) = CachedEntry(object, owners, Set{String}())
CachedEntry(object) = CachedEntry(object, Set{String}())

function SerializationContext(session::Session)
    return SerializationContext(OrderedDict{String,Any}(), session, String[])
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
    # Always register with root session!
    # TODO, this may be a problem for Observable{Observable}
    # since the updates are serialized via the root session then, which means they will never get freed
    root = root_session(session)
    key = cache_key(session, obs)
    # Only register one time
    if !haskey(root.session_objects, key)
        # JSUpdateObservable sends `key` as the wire id, so the browser update
        # and the registration agree (prefixed for proxied sessions).
        updater = JSUpdateObservable(session, key)
        # Don't deregister on root / or session close
        # The updaters callbacks are freed manually in delete_cached!`
        on(updater, obs)
    end
    return
end


function serialize_cached(context::SerializationContext, obs::Observable)
    return add_cached!(context.session, context.message_cache, obs; pins=context.pins) do
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

"""
    add_cached!(create_cached_object::Function, session::Session, message_cache::AbstractDict{String, Any}, key::String; pins=nothing)

Checks if key is already cached by the session or it's root session (we skip any child session between root -> this session).
If not cached already, we call `create_cached_object` to create a serialized form of the object corresponding to `key` and cache it.
We return nothing if already cached, or the serialized object if not cached.
We also handle the part of adding things to the message_cache from the serialization context.
A bare reference the page may read late is pinned on the page: collected in `pins` to go out
with the message, or right away without one.
"""
function add_cached!(create_cached_object::Function, session::Session, send_to_js::AbstractDict{String, Any}, @nospecialize(object);
                     pins::Union{Nothing, Vector{String}}=nothing)::CacheKey
    root = root_session(session)
    lock(root.deletion_lock) do
        key = cache_key(session, object)::String
        result = CacheKey(key)
        # If this session already tracks the key, nothing to do — we
        # already added our id to root's `owners` set the first time.
        # For root, `session.session_objects` IS the entry store, so a bare
        # `haskey` is true even when root never registered as an owner (the
        # entry may have been created by a sub-session). In that case root
        # must still become an owner, otherwise the entry is evicted when the
        # sub closes while root's DOM still references the CacheKey.
        # Check membership in the entry's `owners` set for root instead.
        if session === root
            entry = get(root.session_objects, key, nothing)
            if entry isa CachedEntry && root.id in entry.owners
                return result
            end
        elseif haskey(session.session_objects, key)
            return result
        end
        # Sub sessions keep a marker (value is meaningless — only the
        # presence of the key matters; `free()` iterates these to
        # decrement owner sets at close time).
        if session !== root
            session.session_objects[key] = nothing
        end
        if haskey(root.session_objects, key)
            entry = root.session_objects[key]::CachedEntry
            # Root cache already holds this: register `session.id` as a new
            # owner. A bare TrackingOnly is only safe when the page has read
            # another owner's copy by the time it reads this message
            # (`on_page`), and still holds it then (in order, or pinned).
            # Otherwise ship it again; the page keeps the copy it already has
            # (a static `onclick` and a `map(...)` DOM sharing one Observable,
            # a row in a hidden pane).
            bare = !isempty(entry.on_page)
            send_to_js[key] = bare ? TrackingOnly(key) : create_cached_object()
            push!(entry.owners, session.id)
            if sends_in_order(session)
                push!(entry.on_page, session.id)
            elseif bare
                pins === nothing ? pin_on_page!(connection(root), root, session, [key]) : push!(pins, key)
            end
        else
            # First time anyone in this connection cached this object.
            # IMPORTANT: call `create_cached_object` BEFORE inserting into
            # `root.session_objects`. The closure transitively invokes
            # `register_observable!`, which short-circuits when
            # `haskey(root.session_objects, key)` is already true — so if
            # we insert first, the JS-update listener never gets attached
            # and JS notifies silently fail to reach Julia.
            serialized = create_cached_object()
            entry = CachedEntry(object, Set{String}((session.id,)))
            sends_in_order(session) && push!(entry.on_page, session.id)
            root.session_objects[key] = entry
            send_to_js[key] = serialized
        end
        return result
    end
end

# Whether a message this session serializes now reaches the page after
# everything it sent before, and before anything serialized later: it is
# connected, nothing of it waits in its queue, and `send` serializes and writes
# under one lock. A session that is still loading in the browser is not.
sends_in_order(session::Session) = sends_in_order(connection(session), session)
function sends_in_order(::FrontendConnection, session::Session)
    return isready(session; throw=false) && isempty(session.message_queue)
end
# A static page reads the root's payload before any sub's, and frees nothing.
sends_in_order(::NoConnection, session::Session) = isroot(session)

# `session` got bare references to `keys` in a message the page may read late.
# Have the page track the objects for it now, through the root, ahead of
# whatever frees the sessions whose copy it relies on; the page keeps that
# entry when the session's payload arrives (`init_session`). Caller holds
# `deletion_lock`.
function pin_on_page!(::FrontendConnection, root::Session, session::Session, keys::Vector{String})
    status = isroot(session) ? "root" : "sub"
    evaljs(root, js"$(keys).forEach(key => Bonito.Sessions.track_in_session($(session.id), key, $(status)))")
    return
end
pin_on_page!(::NoConnection, ::Session, ::Session, ::Vector{String}) = nothing

# `session` connected and its queue went out: the page has read its references.
# Caller holds `deletion_lock`.
function mark_on_page!(root::Session, session::Session)
    for (key, value) in (session === root ? root.session_objects : session.session_objects)
        entry = session === root ? value : get(root.session_objects, key, nothing)
        entry isa CachedEntry && session.id in entry.owners && push!(entry.on_page, session.id)
    end
    return
end

function child_has_reference(child::Session, key)
    haskey(child.session_objects, key) && return true
    return any(((id, s),)-> child_has_reference(s, key), child.children)
end

# Match the updater by its cache-key id, not by session: the
# JSUpdateObservable was registered by the FIRST session to serialize the
# observable (see `register_observable!`), which is not necessarily the last
# owner to close. Filtering by `f.session === session` therefore leaks
# updaters (retaining closed Sessions) across connection cycles.
function remove_js_updates!(key::String, observable::Observable)
    filter!(observable.listeners) do (prio, f)
        !(f isa JSUpdateObservable && f.id == key)
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
    intersect!(entry.on_page, entry.owners)
    if isempty(entry.owners)
        pop!(root.session_objects, key)
        if entry.object isa Observable
            remove_js_updates!(key, entry.object)
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
        remove_js_updates!(key, entry.object)
    end
end

