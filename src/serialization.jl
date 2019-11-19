function serialize_websocket(io::IO, message)
    serialize_msgpack(io, message)
end

function serialize_msgpack(io, @nospecialize(obj))
    data = serialize_js(obj) # apply custom, overloadable transformation
    write(io, MsgPack.pack(data))
end

function js_type(type::Symbol, @nospecialize(x))
    return Dict(
        :__javascript_type__ => type,
        :payload => x
    )
end

serialize_js(@nospecialize(x)) = x

function serialize_js(x::Vector{T}) where {T<:Number}
    return js_type(:typed_vector, x)
end

function serialize_js(jso::JSObject)
    return js_type(:JSObject, uuidstr(jso))
end

function serialize_js(x::Union{AbstractArray, Tuple})
    return map(serialize_js, x)
end

function serialize_js(dict::AbstractDict)
    result = Dict()
    for (k, v) in dict
        result[k] = serialize_js(v)
    end
    return result
end

serialize_js(jss::JSString) = jss.source

function serialize_js(jsc::Union{JSCode, JSString})
    return js_type(:js_code, serialize_string(jsc))
end

serialize_string(@nospecialize(x)) = sprint(io-> serialize_string(io, x))
serialize_string(io::IO, jss::JSString) = print(io, jss.source)

function serialize_string(io::IO, jsc::JSCode)
    for elem in jsc.source
        serialize_string(io, elem)
    end
end


function serialize_string(io::IO, @nospecialize(x))
    str = Base64.base64encode(MsgPack.pack(serialize_js(x)))
    println(io, "(decode_base64_msgpack(\"$(str)\"))")
end

serialize_string(io::IO, x::Observable) = print(io, "'", x.id, "'")

function serialize_string(io::IO, node::Node)
    # This relies on jsrender to give each node a unique id under the
    # attribute data-jscall-id. This is a bit brittle
    # improving this would be nice
    print(io, "(document.querySelector('[data-jscall-id=$(repr(uuid(node)))]'))")
end

function serialize_string(io::IO, assets::Set{Asset})
    for asset in assets
        serialize_string(io, asset)
        println(io)
    end
end

function serialize_string(io::IO, asset::Asset)
    if mediatype(asset) == :js
        println(
            io,
            "<script src='$(url(asset))'></script>"
        )
    elseif mediatype(asset) == :css
        println(
            io,
            "<link href = $(repr(url(asset))) rel = \"stylesheet\",  type=\"text/css\">"
        )
    else
        error("Unrecognized asset media type: $(mediatype(asset))")
    end
end

function serialize_string(io::IO, dependency::Dependency)
    print(io, dependency.name)
end
