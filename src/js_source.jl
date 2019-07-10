
function iterate_interpolations(source::String)
    result = Union{Expr, JSString, Symbol}[]
    lastidx = 1; i = 1; lindex = lastindex(source)
    while true
        c = source[i]
        if c == '$'
            if !isempty(lastidx:(i - 1))
                push!(result, JSString(source[lastidx:(i - 1)]))
            end
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

append_source!(x::JSCode, value::String) = push!(x.source, JSString(value))
append_source!(x::JSCode, value::JSString) = push!(x.source, value)
append_source!(x::JSCode, value::JSCode) = append!(x.source, value.source)

"""
Function used to serialize objects interpolated into a JSCode object, e.g.
via:
```julia
var = "hi"
js"console.log(\$var)"
```
When sent to the frontend, the final javascript string will be constructed as:
```julia
"console.log(" * tojsstring(var) * ")"
```
"""
tojsstring(x) = sprint(io-> tojsstring(io, x))
tojsstring(io::IO, x) = JSON3.write(io, x)
tojsstring(io::IO, x::Observable) = print(io, "'", x.id, "'")

# Handle interpolation into javascript
tojsstring(io::IO, x::JSString) = print(io, x.source)
function tojsstring(io::IO, jss::JSCode)
    for elem in jss.source
        tojsstring(io, elem)
    end
end

function tojsstring(io::IO, jsss::AbstractVector{JSCode})
    for elem in jsss
        tojsstring(io, elem)
        println(io)
    end
end
