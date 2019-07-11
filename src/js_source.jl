
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
