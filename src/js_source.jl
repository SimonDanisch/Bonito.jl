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

function Base.show(io::IO, jsc::JSCode)
    print_js_code(io, jsc,  SerializationContext())
end

function print_js_code(io::IO, @nospecialize(object), context)
    serialized = serialize_cached(context, object)
    if serialized isa CacheKey
        print(io, "__lookup_cached('$(serialized.id)')")
    else
        id = pointer_identity(serialized)
        isnothing(id) && error("damn")
        context.message_cache[id] = serialized
        print(io, "__lookup_cached('$(id)')")
    end
    return context
end

function print_js_code(io::IO, x::Number, context)
    print(io, x)
    return context
end

function print_js_code(io::IO, x::String, context)
    print(io, "'", x, "'")
    return context
end

function print_js_code(io::IO, jss::JSString, context)
    print(io, jss.source)
    return context
end

function print_js_code(io::IO, node::Node, context)
    print(io, "document.querySelector('[data-jscall-id=\"$(uuid(node))\"]')")
    return context
end

function print_js_code(io::IO, node::Asset, context)
    print(io, "document.querySelector('[data-jscall-id=\"$(uuid(node))\"]')")
    return context
end

function print_js_code(io::IO, jsc::JSCode, context)
    for elem in jsc.source
        print_js_code(io, elem, context)
    end
    return context
end

function print_js_code(io::IO, jsss::AbstractVector{JSCode}, context)
    for jss in jsss
        print_js_code(io, jss, context)
        println(io)
    end
    return context
end

function jsrender(session::Session, js::JSCode)
    context = SerializationContext()
    code = sprint() do io
        print_js_code(io, js, context)
    end
    data_str = serialize_string(context.data)
    imports = join(import_module.(context.jsmodules), "\n")
    src = """
        $imports
        const __lookup_cache = JSServe.deserialize('$(data_str)')
        $code
    """
    return DOM.script(src, type="module")
end
