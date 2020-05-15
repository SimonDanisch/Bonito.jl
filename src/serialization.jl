function serialize_websocket(io::IO, message)
    serialize_binary(io, message)
end

function serialize_binary(io, @nospecialize(obj))
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

function serialize_js(jso::JSReference)
    refs = flatten_references(jso)
    return js_type(:JSReference, string.(refs))
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
    source, data = JSServe.serialize2string(jsc)
    # We put the source inside a closure
    # Which we then call via func.apply(data)
    # To set this to our data dependencies!
    return js_type(:js_code, Dict(:source => source, :data => serialize_js(data)))
end

function serialize_js(asset::Asset, serializer::UrlSerializer=UrlSerializer())
    file_url = url(asset, serializer)
    if mediatype(asset) == :js
        return DOM.script(;src=file_url, type="text/javascript", charset="utf8")
    elseif mediatype(asset) == :css
        return DOM.link(;href=file_url, rel="stylesheet", type="text/css", charset="utf8")
    elseif mediatype(asset) == :png
        return url(asset)
    else
        error("Unrecognized asset media type: $(mediatype(asset))")
    end
end

# TODO move to msgpack
MsgPack.msgpack_type(::Type{Float16}) = MsgPack.FloatType()
MsgPack.to_msgpack(::MsgPack.FloatType, x::Float16) = Float32(x)
JSON3.StructType(::Type{Hyperscript.Node{Hyperscript.HTMLSVG}}) = JSON3.ObjectType()
MsgPack.msgpack_type(::Type{Hyperscript.Node{Hyperscript.HTMLSVG}}) = MsgPack.MapType()

if isdefined(JSON3, :keyvaluepairs)
    import JSON3: keyvaluepairs
else
    # JSON3 moved this to its own package and isn't re-exporting it anymore
    import JSON3.StructTypes: keyvaluepairs
end

function MsgPack.to_msgpack(::MsgPack.MapType, node::Hyperscript.Node{Hyperscript.HTMLSVG})
    return keyvaluepairs(node)
end

function keyvaluepairs(node::Hyperscript.Node{Hyperscript.HTMLSVG})
    return [
        :tag => getfield(node, :tag),
        :children => serialize_js(getfield(node, :children)),
        serialize_js(getfield(node, :attrs))...
    ]
end

function Base.show(io::IO, jsc::JSCode)
    serialize2string(io, [], jsc)
end
