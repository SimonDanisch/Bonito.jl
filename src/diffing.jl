"""
A list of jsrenderables, that allows fast updating & rendering!
"""
struct DiffList
    children::Vector
    append::Observable{Vector{Any}}
    setindex::Observable{Tuple{Vector{Int}, Any}}
    delete::Observable{Vector{Int}}
    insert::Observable{Tuple{Int, Any}}
    empty::Observable{Bool}
    attributes::Dict{Symbol, Any}
end

function DiffList(children::Vector; attributes...)
    return DiffList(
        children,
        Observable(Any[]),
        Observable{Tuple{Vector{Int}, Any}}((Int[], Any[])),
        Observable(Int[]),
        Observable{Tuple{Int64, Any}}((0, nothing)),
        Observable(false),
        Dict{Symbol, Any}(attributes)
    )
end

Hyperscript.children(difflist::DiffList) = difflist.children

"""
    connect!(observable_list::Observable{<:AbstractVector}, difflist::DiffList)
Connects an Observable list with the events (empty, append, setindex, delete, insert) from
`difflist`.
"""
function connect!(observable_list::Observable{<:AbstractVector}, difflist::DiffList)
    if observable_list[] != difflist.children
        empty!(observable_list[])
        append!(observable_list[], difflist.children)
    end
    on(difflist.empty) do bool
        empty!(observable_list[])
        observable_list[] = observable_list[]
    end

    on(difflist.append) do values
        append!(observable_list[], values)
        observable_list[] = observable_list[]
    end

    on(difflist.setindex) do (indices, values)
        observable_list[][indices] = values
        observable_list[] = observable_list[]
    end

    on(difflist.setindex) do (indices, values)
        observable_list[][indices] = values
        observable_list[] = observable_list[]
    end

    on(difflist.delete) do indices
        i = 0
        filter!(x->(i+=1; !(i in indices)), observable_list[])
        observable_list[] = observable_list[]
    end

    on(difflist.insert) do (index, item)
        insert!(observable_list[], index, item)
        observable_list[] = observable_list[]
    end
end

function Base.empty!(difflist::DiffList)
    difflist.empty[] = true
    empty!(children(difflist))
end

Base.push!(difflist::DiffList, value) = append!(difflist, [value])

function Base.append!(difflist::DiffList, values::Vector)
    difflist.append[] = values
    append!(children(difflist), values)
    return values
end

Base.setindex!(difflist::DiffList, value, idx::Integer) = setindex!(difflist, [value], Int[idx])

function Base.setindex!(difflist::DiffList, values::Vector, idx::Union{Integer, AbstractVector{<: Integer}, AbstractRange})
    indices = convert(Vector{Int}, idx)
    length(values) != length(indices) && error("Dimensions must match!")
    difflist.setindex[] = (indices, values)
    children(difflist)[indices] = values
    return values
end

function Base.delete!(difflist::DiffList, idx::Union{Integer, AbstractVector{<: Integer}, AbstractRange})
    indices = idx isa Integer ? Int[idx] : convert(Vector{Int}, idx)
    difflist.delete[] = indices
    i = 0
    filter!(x->(i+=1; !(i in idx)), children(difflist))
    return idx
end

function Base.insert!(difflist::DiffList, index::Integer, item)
    difflist.insert[] = (Int(index), item)
    insert!(children(difflist), index, item)
end

function replace_children(difflist::DiffList, list::Vector; batch = 100)
    empty!(difflist)
    isempty(list) && return
    append_lock = Ref(true)
    @async begin
        for i in 1:batch:length(list)
            # TODO replace with lock!
            # The problem is, if I replace this with a SpinLock / ReentrantLock
            # It will block on unlock, even though I verify before that the lock
            # is unlocked
            while !append_lock[]
                yield()
            end
            append_lock[] = false
            append!(difflist, list[i:min(i - 1 + batch, length(list))])
            append_lock[] = true
        end
    end
end

function JSServe.jsrender(session::JSServe.Session, difflist::DiffList)
    # We start with an ampty node, to not stress rendering too much!
    # We will fill the div async after creation.
    node = DOM.div(; difflist.attributes...)

    append = map(difflist.append) do values
        return JSServe.jsrender.((session,), values)
    end

    onjs(session, append, js"""function (nodes){
        var nodes_array = materialize(nodes);
        var node = $(node);
        for(var idx in nodes_array){
            node.appendChild(nodes_array[idx]);
        }
    }""")

    setindex = map(difflist.setindex) do (indices, values)
        return (indices, JSServe.jsrender.((session,), values))
    end

    onjs(session, setindex, js"""function (indices_children){
        var indices = deserialize_js(indices_children[0]); // 1 based indices
        var children = materialize(indices_children[1]);
        // children.length == indices.length should be checked in julia
        var node = $(node);
        for(var idx in children){
            var replace = node.children[indices[idx] - 1];
            node.replaceChild(children[idx], replace);
        }
    }""")

    onjs(session, difflist.delete, js"""function (indices){
        var indices = deserialize_js(indices);
        var node = $(node);
        var children2remove = indices.map(x=> node.children[x - 1]);
        for(var idx in children2remove){
            node.removeChild(children2remove[idx]);
        }
    }""")

    insert = map(difflist.insert) do (index, element)
        if element !== nothing
            return (index, JSServe.jsrender(session, element))
        else
            (index, nothing)
        end
    end
    onjs(session, insert, js"""function (index_element){
        var node = $(node);
        var element = materialize(index_element[1]);
        node.insertBefore(element, node.children[index_element[0] - 1]);
    }""")

    onjs(session, difflist.empty, js"""function (empty){
        var node = $(node);
        while (node.firstChild) {
            node.removeChild(node.firstChild);
        }
    }""")
    # Schedule to fill in nodes async & batched
    # copy == otherwise it will call empty! on children(difflist)
    # before replacing!
    replace_children(difflist, copy(children(difflist)))

    return node
end
