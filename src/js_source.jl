
function iterate_interpolations(source::String)
    result = Union{Expr, JSString, Symbol}[]
    lastidx = 1; i = 1; lindex = lastindex(source)
    while true
        c = source[i]
        if c == '$'
            # add elements before $
            if !isempty(lastidx:(i - 1))
                push!(result, JSString(source[lastidx:(i - 1)]))
            end
            # parse the $ expression
            expr, i2 = Meta.parse(source, i + 1, greedy = false, raise = false)
            if i2 >= lindex && expr === nothing
                error("Invalid interpolation at index $(i)-$(lindex): $(source[i:lindex])")
            end
            i = i2
            push!(result, esc(expr))
            lastidx = i
            i > lindex && break
        else
            if i == lindex
                if !isempty(lastidx:lindex)
                    push!(result, JSString(source[lastidx:lindex]))
                end
                break
            end
            i = Base.nextind(source, i)
        end
    end
    return result
end

macro js_str(js_source)
    value_array = :([])
    append!(value_array.args, iterate_interpolations(js_source))
    return :(JSCode($value_array))
end

function serialize2string(@nospecialize(x))
    data_dependencies = []
    source = sprint() do io
        serialize2string(io, data_dependencies, x)
    end
    return source, data_dependencies
end

function serialize2string(io::IO, data_dependencies::Vector{Any}, @nospecialize(any))
    idx = length(data_dependencies) # idx before push --> JS is 0 indexed
    push!(data_dependencies, any)
    # TODO how do we call this?
    print(io, "deserialize_js(__data_dependencies[$(idx)])")
end

function serialize2string(io::IO, data_dependencies::Vector{Any}, x::JSString)
    print(io, x.source)
end

function serialize2string(io::IO, data_dependencies::Vector{Any}, x::Union{Symbol, String})
    print(io, "'", x, "'")
end

function serialize2string(io::IO, data_dependencies::Vector{Any}, x::Number)
    print(io,  x)
end

function serialize2string(io::IO, data_dependencies::Vector{Any}, jsc::JSCode)
    for elem in jsc.source
        serialize2string(io, data_dependencies, elem)
    end
end

function serialize2string(io::IO, data_dependencies::Vector{Any}, jsss::AbstractVector{JSCode})
    for jss in jsss
        serialize2string(io, data_dependencies, jss)
        println(io)
    end
end

function serialize2string(io::IO, data_dependencies::Vector{Any}, jso::JSObject)
    serialize2string(io, data_dependencies, js"get_heap_object($(uuidstr(jso)))")
end

function serialize2string(io::IO, data_dependencies::Vector{Any}, jso::Dependency)
    print(io, jso.name)
end


function flatten_references(jso::JSObject, refs = Union{String, Symbol}[])
    if getfield(jso, :typ) == :Module
        pushfirst!(refs, getfield(jso, :name))
    else
        pushfirst!(refs, uuidstr(jso))
    end
    return refs
end

function flatten_references(jso::JSReference, refs = Union{String, Symbol}[])
    pushfirst!(refs, getfield(jso, :name))
    flatten_references(getfield(jso, :parent), refs)
end

function js_name(reference::JSReference)
    names = flatten_references(reference)
    parent = if names[1] isa String
        js"get_heap_object($(names[1]))"
    else
        names[1]
    end
    if length(names) >= 2 && names[2] == :new
        name = JSString(join([parent; names[3:end];], "."))
        return js"new $(name)"
    else
        name = JSString(join([parent,  names[2:end]...], "."))
        return js"$(name)"
    end
end

function serialize2string(io::IO, data_dependencies::Vector{Any}, jso::JSReference)
    serialize2string(io, data_dependencies, js_name(jso))
end

function serialize2string(io::IO, data_dependencies::Vector{Any}, observable::Observable)
    print(io, "'", observable.id, "'")
end

# Handle interpolating into Javascript
function serialize2string(io::IO, data_dependencies::Vector{Any}, node::Node)
    # This relies on jsrender to give each node a unique id under the
    # attribute data-jscall-id. This is a bit brittle
    # improving this would be nice
    print(io, "(document.querySelector('[data-jscall-id=$(repr(uuid(node)))]'))")
end
