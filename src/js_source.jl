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

function Base.show(io::IO, jsc::JSCode)
    print_js_code(io, jsc, IdDict())
end

function print_js_code(io::IO, @nospecialize(object), objects::IdDict)
    id = get!(()-> string(hash(object)), objects, object)
    print(io, "__lookup_interpolated('$(id)')")
    return objects
end

function print_js_code(io::IO, x::Number, objects::IdDict)
    print(io, x)
    return objects
end

function print_js_code(io::IO, x::String, objects::IdDict)
    print(io, "'", x, "'")
    return objects
end

function print_js_code(io::IO, jss::JSString, objects::IdDict)
    print(io, jss.source)
    return objects
end

function print_js_code(io::IO, node::Node, objects::IdDict)
    print(io, "document.querySelector('[data-jscall-id=\"$(uuid(node))\"]')")
    return objects
end

function print_js_code(io::IO, jsc::JSCode, objects::IdDict)
    for elem in jsc.source
        print_js_code(io, elem, objects)
    end
    return objects
end

function print_js_code(io::IO, jsss::AbstractVector{JSCode}, objects::IdDict)
    for jss in jsss
        print_js_code(io, jss, objects)
        println(io)
    end
    return objects
end

function print_js_code(io::IO, asset::Asset, objects::IdDict)
    if asset.es6module
        get!(() -> string(hash(asset)), objects, asset)
        print(io, "import(window.JSSERVE_IMPORTS['$(unique_key(asset))'])")
    else
        id = get!(() -> string(hash(asset)), objects, asset)
        print(io, "__lookup_interpolated('$(id)')")
    end
    return objects
end


# This works better with Pluto, which doesn't allow <script> the script </script>
# and only allows `<script src=url>  </script>`
# TODO, NoServer is kind of misussed here, since Pluto happens to use it
# I guess the best solution would be a trait system or some other config object
# for deciding how to inline code into pure HTML
function inline_code(session::Session, noserver, source::String)
    data_url = to_data_url(source, "application/javascript")
    return DOM.script(src=data_url)
end

function inline_code(session::Session, asset_server, js::JSCode)
    objects = IdDict()
    # Print code while collecting all interpolated objects in an IdDict
    code = sprint() do io
        print_js_code(io, js, objects)
    end

    # TODO, give imports their own dict?
    filter!(objects) do (k, v)
        if k isa Asset
            session.session_objects[object_identity(k)] = k
            return false
        else
            return true
        end
    end

    if isempty(objects)
        src = code
    else
        # reverse lookup and serialize elements
        interpolated_objects = Dict(v => k for (k, v) in objects)
        data_str = serialize_string(session, interpolated_objects)
        src = """
            import(JSSERVE_IMPORTS['$(unique_key(JSServeLib))']).then(JSServe => {
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
