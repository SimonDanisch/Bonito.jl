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
        Observable((Int[], Any[])),
        Observable(Int[]),
        Observable((0, nothing)),
        Observable(false),
        Dict{Symbol, Any}(attributes)
    )
end

Hyperscript.children(diffnode::DiffList) = diffnode.children

Base.empty!(diffnode::DiffList) = diffnode.empty[] = true
Base.push!(diffnode::DiffList, value::Hyperscript.Node) = append!(diffnode, [value])

function Base.append!(diffnode::DiffList, values::Vector)
    diffnode.append[] = values
    append!(children(diffnode), values)
    return values
end

Base.setindex!(diffnode::DiffList, value, idx::Integer) = setindex!(diffnode, [value], Int[idx])

function Base.setindex!(diffnode::DiffList, values::Vector, idx::Union{Integer, AbstractVector{<: Integer}, AbstractRange})
    indices = convert(Vector{Int}, idx)
    length(values) != length(indices) && error("Dimensions must match!")
    diffnode.setindex[] = (indices, values)
    children(diffnode)[indices] = values
    return values
end

function Base.delete!(diffnode::DiffList, idx::Union{Integer, AbstractVector{<: Integer}, AbstractRange})
    indices = idx isa Integer ? Int[idx] : convert(Vector{Int}, idx)
    diffnode.delete[] = indices
    for idx in indices
        splice!(children(diffnode), idx)
    end
    return values
end

function Base.insert!(diffnode::DiffList, index::Integer, item)
    diffnode.insert[] = (Int(index), item)
    insert!(children(diffnode), index, item)
end

function replace_children(diffnode::DiffList, list::Vector; batch = 100)
    #TODO, maybe diff this!?
    # async & batches: we assume it's pretty slow to upload whole list at once!
    # TODO we need a lock for this!
    @async begin
        empty!(diffnode)
        for i in 1:batch:length(list)
            append!(diffnode, list[i:min(i - 1 + batch, length(list))])
            yield()
        end
    end
end

function JSServe.jsrender(session::JSServe.Session, diffnode::DiffList)
    # We start with an ampty node, to not stress rendering too much!
    # We will fill the div async after creation.
    node = DOM.div(; diffnode.attributes...)

    append = map(diffnode.append) do values
        return JSServe.jsrender.((session,), values)
    end
    push!(session, append)

    onjs(session, append, js"""function (nodes){
        var nodes_array = materialize(nodes);
        var node = $(node);
        for(var idx in nodes_array){
            node.appendChild(nodes_array[idx]);
        }
    }""")

    setindex = map(diffnode.setindex) do (indices, values)
        return (indices, JSServe.jsrender.((session,), values))
    end
    push!(session, setindex)

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

    push!(session, diffnode.delete)
    onjs(session, diffnode.delete, js"""function (indices){
        var indices = deserialize_js(indices);
        var node = $(node);
        for(var idx in indices){
            node.removeChild(node.children[indices[idx] - 1]);
        }
    }""")

    insert = map(diffnode.insert) do (index, element)
        if element !== nothing
            return (index, JSServe.jsrender(session, element))
        else
            (index, nothing)
        end
    end
    push!(session, insert)
    onjs(session, insert, js"""function (index_element){
        var node = $(node);
        var element = materialize(index_element[1]);
        node.insertBefore(element, node.children[index_element[0] - 1]);
    }""")

    push!(session, diffnode.empty)
    onjs(session, diffnode.empty, js"""function (empty){
        var node = $(node);
        while (node.firstChild) {
            node.removeChild(node.firstChild);
        }
    }""")

    # Schedule to fill in nodes async & batched
    replace_children(diffnode, children(diffnode))

    return node
end
