function serialize_websocket(io::IO, message)
    serialize_binary(io, message)
end

function serialize_binary(io, @nospecialize(obj))
    data = serialize_js(obj) # apply custom, overloadable transformation
    @show isopen(io)
    write(io, MsgPack.pack(data))
end

function js_type(type::Symbol, @nospecialize(x))
    return Dict(
        :__javascript_type__ => type,
        :payload => x
    )
end

serialize_js(@nospecialize(x)) = x

function serialize_js_value(x::Observable)
    js_type(:Observable, Dict(:id=>x.id, :value=>serialize_js(x[])))
end

serialize_js(x::Observable) = string(x.id)

function serialize_js(node::Node)
    js_type(:DomNode, uuid(node))
end

function serialize_js(x::Vector{T}) where {T<:Number}
    return js_type(:typed_vector, x)
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
    context = []
    js_string = sprint(io-> print_js_code(io, jsc, context))
    data = Dict("source" => js_string, "context" => context)
    return js_type(:js_code, data)
end

function serialize_js(asset::Asset)
    return url(asset)
end

MsgPack.msgpack_type(::Type{Float16}) = MsgPack.FloatType()
MsgPack.to_msgpack(::MsgPack.FloatType, x::Float16) = Float32(x)
MsgPack.msgpack_type(::Type{Hyperscript.Node{Hyperscript.HTMLSVG}}) = MsgPack.MapType()
function MsgPack.to_msgpack(::MsgPack.MapType, node::Hyperscript.Node{Hyperscript.HTMLSVG})
    return keyvaluepairs(node)
end

function keyvaluepairs(node::Hyperscript.Node{Hyperscript.HTMLSVG})
    return [
        :tag => getfield(node, :tag),
        :children => getfield(node, :children),
        getfield(node, :attrs)...
    ]
end
