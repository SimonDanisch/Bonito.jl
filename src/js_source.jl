function iterate_interpolations(source::String, result=Union{Expr,JSString,Symbol}[], text_func=JSString)
    lastidx = 1; i = 1; lindex = lastindex(source)
    isempty(source) && return result
    while true
        c = source[i]

        # Attempt to parse + interpolate all "$..." expressions, except for "${ ... }"
        # which is a template literal placeholder in Javascript.
        #
        # "{ ... }" is a deprecated syntax in Julia, so this is fine.
        if c == '$' && i != lindex && source[i + 1] != '{'
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

function import_in_js(io::IO, session::Session, asset_server, asset::BinaryAsset)
    print(io, "Bonito.fetch_binary('$(url(session, asset))')")
end

function import_in_js(io::IO, session::Session, asset_server, asset::Asset)
    ref = url(session, asset)
    if asset.es6module
        # Use absolute paths for es6modules, since they're not relative
        # To the HTML file they're used in, but instead to the Bonito.js file
        # TODO, teach Bonito about where the JS files are located,
        # to make them relativ
        # Should only be relevant for AssetFolder
        if startswith(ref, ".")
            ref = ref[2:end]
        end
        print(io, "import('$(ref)')")
    else
        print(io, "Bonito.fetch_binary($(ref))")
    end
end

function print_js_code(io::IO, asset::Union{Asset, BinaryAsset}, context::JSSourceContext)
    if asset isa BinaryAsset || asset.es6module
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


# This works better with Pluto, which doesn't allow <script> the script </script>
# and only allows `<script src=url>  </script>`
# TODO, NoServer is kind of misussed here, since Pluto happens to use it
# I guess the best solution would be a trait system or some other config object
# for deciding how to inline code into pure HTML
function inline_code(session::Session, noserver, source::String)
    return DOM.script(source; type="module")
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
        Bonito.OBJECT_FREEING_LOCK.lock(() => {
            Bonito.fetch_binary('$(url(session, binary))').then(bin_messages=>{
                const objects = Bonito.decode_binary(bin_messages, $(session.compression_enabled));
                const __lookup_interpolated = (id) => objects[id]
                $code
            })
        })
        """
    end
    return inline_code(session, asset_server, src)
end

function jsrender(session::Session, js::JSCode)
    # Make how we inline the code conditional on the way we serve files!
    return inline_code(session, session.asset_server, js)
end
