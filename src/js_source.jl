function iterate_interpolations(source::String)
    result = Union{Expr, JSString, Symbol}[]
    lastidx = 1; i = 1; lindex = lastindex(source)
    isempty(source) && return result
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
    return :(JSCode($value_array, $(string(__source__.file, ":", __source__.line))))
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

function print_js_code(io::IO, x::String, context::JSSourceContext)
    print(io, "'", x, "'")
    return context
end

function print_js_code(io::IO, jss::JSString, context::JSSourceContext)
    print(io, jss.source)
    return context
end

function print_js_code(io::IO, node::Node, context::JSSourceContext)
    print(io, "document.querySelector('[data-jscall-id=\"$(uuid(node))\"]')")
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

function import_in_js(io::IO, session::Session, asset_server, asset::Asset)
    # print(io, "import(window.JSSERVE_IMPORTS['$(unique_key(asset))'])")
    print(io, "import('$(url(session, asset))')")
end

function print_js_code(io::IO, asset::Asset, context::JSSourceContext)
    if asset.es6module
        bundle!(asset) # no-op if not needed
        session = context.session
        if !isnothing(session)
            import_in_js(io, session, session.asset_server, asset)
            push!(session.imports, asset)
            push!(root_session(session).imports, asset)
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
    # TODO, give imports their own dict?
    if isempty(context.objects)
        src = code
    else
        # reverse lookup and serialize elements
        interpolated_objects = Dict(v => k for (k, v) in context.objects)
        data_str = serialize_string(session, interpolated_objects)
        jslib = sprint(io -> print_js_code(io, JSServeLib, context))
        src = """
            $(jslib).then(JSServe => {
                // JSCode from $(js.file)
                const data_str = '$(data_str)'
                JSServe.decode_base64_message(data_str).then(objects=> {
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
