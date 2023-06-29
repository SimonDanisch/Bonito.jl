function iterate_interpolations(source::String, result=Union{Expr,JSString,Symbol}[], text_func=JSString)
    lastidx = 1; i = 1; lindex = lastindex(source)
    isempty(source) && return result
    while true
        c = source[i]
        if c == '$'
            # add elements before $
            if !isempty(lastidx:(i - 1))
                push!(result, text_func(source[lastidx:(i-1)]))
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
                    push!(result, text_func(source[lastidx:lindex]))
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
    return :(JSCode($value_array, $(string(__source__.file, ":", __source__.line))))
end

macro dom_str(str)
    result = iterate_interpolations(str, [], string)
    return :(DOM.div($(result...)))
end

JSCode(source::String) = JSCode([JSString(source)])

function merge_js(iterable_of_js_code)
    merged_js = JSCode()
    for js in iterable_of_js_code
        # Put into closure, to create its own scope and make sure to not drop file!
        js_sanitized = js"""
            /*File: $(js.file)*/
            (()=> {
                $js
            })();
        """
        append!(merged_js.source, js_sanitized.source)
    end
    return merged_js
end

struct JSSourceContext
    session::Union{Nothing,Session}
    objects::IdDict
end

function JSSourceContext(session::Union{Nothing,Session}=nothing)
    return JSSourceContext(session, IdDict())
end

function Base.show(io::IO, jsc::JSCode)
    print_js_code(io, jsc, JSSourceContext())
end

function print_js_code(io::IO, @nospecialize(object), context::JSSourceContext)
    id = get!(() -> string(hash(object)), context.objects, object)
    print(io, "__lookup_interpolated('$(id)')")
    return context
end

function print_js_code(io::IO, x::Number, context::JSSourceContext)
    print(io, x)
    return context
end

function print_js_code(io::IO, x::Union{Symbol, AbstractString}, context::JSSourceContext)
    print(io, "'", x, "'")
    return context
end

function print_js_code(io::IO, jss::JSString, context::JSSourceContext)
    print(io, jss.source)
    return context
end

function print_js_code(io::IO, node::Node, context::JSSourceContext)
    session = context.session # can be nothing
    print(io, "document.querySelector('[data-jscall-id=\"$(uuid(session, node))\"]')")
    return context
end

function print_js_code(io::IO, jsc::JSCode, context::JSSourceContext)
    for elem in jsc.source
        print_js_code(io, elem, context)
    end
    return context
end

function print_js_code(io::IO, jsss::AbstractVector{JSCode}, context::JSSourceContext)
    for jss in jsss
        print_js_code(io, jss, context)
        println(io)
    end
    return context
end


is_es6module(asset) = false
is_es6module(asset::Asset) = asset.es6module

function print_js_code(io::IO, asset::AbstractAsset, context::JSSourceContext)
    if asset isa BinaryAsset || is_es6module(asset)
        bundle!(asset) # no-op if not needed
        session = context.session
        if !isnothing(session)
            import_in_js(io, session, session.asset_server, asset)
        else
            # This should be mainly for `print(jscode)`
            print(io, "import('$(get_path(asset))')")
        end
    else
        id = get!(() -> string(hash(asset)), context.objects, asset)
        print(io, "__lookup_interpolated('$(id)')")
    end
    return context
end


function inline_code(session::Session, asset_server, js::JSCode)
    # Print code while collecting all interpolated objects in an IdDict
    context = JSSourceContext(session)

    code = sprint() do io
        print_js_code(io, js, context)
    end
    if isempty(context.objects)
        src = code
    else
        # reverse lookup and serialize elements

        interpolated_objects = Dict(v => k for (k, v) in context.objects)
        binary = BinaryAsset(session, interpolated_objects)
        src = """
            // JSCode from $(js.file)
            JSServe.fetch_binary('$(url(session, binary))').then(bin_messages=>{
                const objects = JSServe.decode_binary(bin_messages, $(session.compression_enabled));
                const __lookup_interpolated = (id) => objects[id]
                $code
            })
        """
    end
    return inline_code(session, asset_server, src)
end

function jsrender(session::Session, js::JSCode)
    # Make how we inline the code conditional on the way we serve files!
    return inline_code(session, session.asset_server, js)
end
