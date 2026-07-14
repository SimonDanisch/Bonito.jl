# Fine-grained list of widgets with stable per-item identity. Diffs an
# `Observable{Vector{T}}` against the previously shipped key list and
# emits the minimum DOM ops (insert/remove/move). Survivors keep their
# JS-side bindings; no remount.

const KeyedListLib = ES6Module(
    joinpath(@__DIR__, "..", "..", "js_dependencies", "KeyedList.js"))

mutable struct KeyedList{T}
    items :: Observable{Vector{T}}
    keyfn :: Function
    last_keys :: Vector{String}
end

"""
    KeyedList(items::Observable{Vector{T}}; key = hash) -> KeyedList

`T` must have a `Bonito.jsrender(::Session, ::T)` method. `key(item)`
derives the stable identity used for diffing. Default `hash` works for
widgets held by stable instance across rebuilds (cache them in a Dict
keyed by their natural id and re-emit the same instances each render).
"""
function KeyedList(items::Observable{Vector{T}};
                    key::Function = hash) where {T}
    hasmethod(jsrender, Tuple{Session, T}) ||
        error("KeyedList items must have a Bonito.jsrender(session, ::$T) method")
    KeyedList{T}(items, key, String[])
end

# Returns (inserts, removes, moves). `after_key` is the key that should
# precede the item (nothing = prepend). For inserts we also return the
# source index so the caller can fetch the widget without a second pass.
function diff_keyed_list(old_keys::Vector{String}, new_keys::Vector{String})
    old_set = Set(old_keys)
    new_set = Set(new_keys)

    removes = [k for k in old_keys if k ∉ new_set]
    inserts = Tuple{String, Union{String,Nothing}, Int}[]
    moves   = Tuple{String, Union{String,Nothing}}[]

    for (i, k) in enumerate(new_keys)
        after = i == 1 ? nothing : new_keys[i - 1]
        if k ∉ old_set
            push!(inserts, (k, after, i))
        else
            old_idx = findfirst(==(k), old_keys)
            prev_survivor = nothing
            for j in (old_idx - 1):-1:1
                if old_keys[j] in new_set
                    prev_survivor = old_keys[j]
                    break
                end
            end
            after == prev_survivor || push!(moves, (k, after))
        end
    end

    return (; inserts, removes, moves)
end

function jsrender(session::Session, list::KeyedList)
    ops_obs = Observable(Any[])

    container = DOM.div(;
                         class = "bonito-keyed-list",
                         style = Styles("display" => "contents"))

    # Stub setup MUST be queued before any initial ship_keyed_insert!:
    # in an UNINITIALIZED subsession, sends queue into message_queue and
    # flush in order on JS, so the stub must be in place when the inserts
    # run. `lib.attach()` later replaces the stub with a real KeyedList
    # instance and drains pending.
    evaljs(session, js"""
        const c = $(container);
        c.bonitoKeyedList = {
            pending: [],
            insertItem(key, after_key, elem) {
                this.pending.push({key, after_key, elem});
            },
        };
        $(KeyedListLib).then(lib => lib.attach(c, $(ops_obs)));
    """)

    initial_items = list.items[]
    initial_keys  = String[string(list.keyfn(x)) for x in initial_items]
    list.last_keys = copy(initial_keys)
    for (i, x) in enumerate(initial_items)
        after = i == 1 ? nothing : initial_keys[i - 1]
        ship_keyed_insert!(session, container, initial_keys[i], after, x)
    end

    on(session, list.items) do new_items
        new_keys = String[string(list.keyfn(x)) for x in new_items]
        d = diff_keyed_list(list.last_keys, new_keys)

        # Inserts first so any move that references a fresh key sees it.
        for (k, after_k, src_i) in d.inserts
            ship_keyed_insert!(session, container, k, after_k, new_items[src_i])
        end

        ops = Any[]
        for k in d.removes
            push!(ops, Dict("type" => "remove", "key" => k))
        end
        for (k, after_k) in d.moves
            push!(ops, Dict("type" => "move", "key" => k, "after_key" => after_k))
        end
        isempty(ops) || (ops_obs[] = ops)

        list.last_keys = new_keys
        return nothing
    end

    return jsrender(session, container)
end

function ship_keyed_insert!(session::Session,
                             container,
                             key::String,
                             after_key::Union{String,Nothing},
                             widget)
    dom_in_js(session, widget, js"""(elem) => {
        const c = $(container);
        if (c && c.bonitoKeyedList) {
            c.bonitoKeyedList.insertItem($(key), $(after_key), elem);
        }
    }""")
    return nothing
end
