
abstract type JavascriptSerializer <: IO end

"""
    io_object(io::JavascriptSerializer)
gets the IO object of a JavascriptSerializer
"""
io_object(io::JavascriptSerializer) = io.io


struct JSONSerializer{T <: IO} <: JavascriptSerializer
    io::T
end

# Overload base functions for any object inheriting from JavascriptSerializer
for func in (:write, :print, :println)
    @eval Base.$(func)(io::JavascriptSerializer, args...) = $(func)(io_object(io), args...)
end
Base.print(io::JavascriptSerializer, arg::Union{SubString{String}, String}) = print(io_object(io), arg)
Base.print(io::JavascriptSerializer, arg::Char) = print(io_object(io), arg)

Base.write(io::JSServe.JavascriptSerializer, x::Array) = write(JSServe.io_object(io), x)
Base.write(io::JSServe.JavascriptSerializer, arg::UInt8) = Base.write(io_object(io), arg)

function serialize_websocket(io::IO, message)
    # right now, we simply use
    str = sprint() do io2
        serialize_string(JSONSerializer(io2), message)
    end
    write(io, str)
end


"""
Function used to serialize objects interpolated into a JS string, e.g.
via:
```julia
var = "hi"
js"console.log(\$var)"
```
When sent to the frontend, the final javascript string will be constructed as:
```julia
"console.log(" * serialize_string(var) * ")"
```
"""
serialize_string(@nospecialize(object)) = sprint(io-> serialize_string(io, object))
serialize_string(io::IO, @nospecialize(object)) = JSON3.write(io, object)
serialize_string(io::IO, x::Observable) = print(io, "'", x.id, "'")

# Handle interpolation into javascript
function serialize_string(jsio::JSONSerializer, jss::JSCode)
    # serialize as string
    serialize_string(jsio, serialize_string(jss))
end

serialize_string(io::IO, x::JSString) = print(io, x.source)
function serialize_string(io::IO, jss::JSCode)
    for elem in jss.source
        serialize_string(io, elem)
    end
end
function serialize_string(io::IO, jsss::AbstractVector{JSCode})
    for jss in jsss
        serialize_string(io, jss)
        println(io)
    end
end

struct AsJSON{T}
    x::T
end

serialize_string(io::JSONSerializer, js::AsJSON) = serialize_string(io, js.x)

function serialize_string(io::IO, js::AsJSON)
    serialize_string(JSONSerializer(io), js.x)
end

# Since there is no easy way to mess with JSON3 printer, we print
# Vectors & Dictionaries ourselves, so that we cann apply serialize_string recursively
function serialize_string(io::IO, vector::Union{AbstractVector, Tuple})
    print(io, '[')
    for (i, element) in enumerate(vector)
        serialize_string(io, element)
        (i == length(vector)) || print(io, ',') # dont print for last item
    end
    print(io, ']')
end

function serialize_string(io::IO, dict::Union{NamedTuple, AbstractDict})
    print(io, '{')
    for (i, (key, value)) in enumerate(pairs(dict))
        serialize_string(io, key); print(io, ':')
        serialize_string(io, value)
        (i == length(dict)) || print(io, ',') # dont print for last item
    end
    print(io, '}')
end

# function deserialize_js(::JSObject)
#     # deserialize with the function get_heap_object
#     return js"get_heap_object"
# end
