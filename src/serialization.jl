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
    return js_type(:js_code, serialize_readable(jsc))
end

serialize_readable(@nospecialize(x)) = sprint(io-> serialize_readable(io, x))
serialize_readable(io::IO, @nospecialize(object)) = JSON3.write(io, object)
serialize_readable(io::IO, x::JSString) = print(io, x.source)

function serialize_readable(io::IO, jsc::JSCode)
    for elem in jsc.source
        serialize_readable(io, elem)
    end
end

function serialize_readable(io::IO, jsss::AbstractVector{JSCode})
    for jss in jsss
        serialize_readable(io, jss)
        println(io)
    end
end

# Since there is no easy way to mess with JSON3 printer, we print
# Vectors & Dictionaries ourselves, so that we cann apply serialize_readable recursively
function serialize_readable(io::IO, vector::AbstractArray{T}) where {T<:Number}
    JSON3.write(io, vector)
end

function serialize_readable(io::IO, vector::AbstractVector{T}) where {T<:Number}
    JSON3.write(io, vector)
end

function serialize_readable(io::IO, vector::Union{AbstractVector, Tuple})
    print(io, '[')
    for (i, element) in enumerate(vector)
        serialize_readable(io, element)
        (i == length(vector)) || print(io, ',') # dont print for last item
    end
    print(io, ']')
end

function serialize_readable(io::IO, dict::Union{NamedTuple, AbstractDict})
    print(io, '{')
    for (i, (key, value)) in enumerate(pairs(dict))
        serialize_readable(io, key); print(io, ':')
        serialize_readable(io, value)
        (i == length(dict)) || print(io, ',') # dont print for last item
    end
    print(io, '}')
end

function serialize_readable(io::IO, jso::JSObject)
    serialize_readable(io, js"get_heap_object($(uuidstr(jso)))")
end

function serialize_readable(io::IO, assets::Set{Asset})
    for asset in assets
        serialize_readable(io, asset)
        println(io)
    end
end

function serialize_readable(io::IO, asset::Asset)
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

function serialize_readable(io::IO, dependency::Dependency)
    print(io, dependency.name)
end

serialize_readable(io::IO, x::Observable) = print(io, "'", x.id, "'")

# Handle interpolating into Javascript
function serialize_readable(io::IO, node::Node)
    # This relies on jsrender to give each node a unique id under the
    # attribute data-jscall-id. This is a bit brittle
    # improving this would be nice
    print(io, "(document.querySelector('[data-jscall-id=$(repr(uuid(node)))]'))")
end

# TODO move to msgpack
MsgPack.msgpack_type(::Type{Float16}) = MsgPack.FloatType()
MsgPack.to_msgpack(::MsgPack.FloatType, x::Float16) = Float32(x)


function Base.show(io::IO, jsc::JSCode)
    serialize_readable(io, jsc)
end
