
debugser(x, level) = nothing;#println(" "^level, typeof(x))
debugser(x::Observable, level) = nothing# println(" "^level, x.id)

function debugser(node::Node, level)
    # return println(" "^level, "DOM")
end

function debugser(x::Vector{T}, level) where {T<:Number}
    # return println(" "^level, "TypedVector: ", T)
end

function debugser(x::Union{AbstractArray, Tuple}, level)
    return foreach(x-> debugser(x, level+1), x)
end

function debugser(dict::AbstractDict, level)
    if haskey(dict, "__javascript_type__")
        print(" "^level, dict["__javascript_type__"])
        if dict["__javascript_type__"] == "Reference"
            println(dict["payload"])
        else
            println()
        end
    else
        for (k, v) in dict
            # println(" "^level, k, ":")
            debugser(v, level + 1)
        end
    end
end

debugser(jss::JSString, level) = nothing#println(" "^level, "JSCode")

function debugser(jsc::JSCode, level)
    # println(" "^level, "JSCode")
end

function debugser(asset::Asset, level)
    # println(" "^level, "Asset")
end


function printsize(name, x)
    sz = Base.summarysize(x)
    if sz/10^6 > 0.01
        @info(name, " > ", Base.format_bytes(sz))
    end
end

debug_size(x, level) = printsize(typeof(x), x);#println(" "^level, typeof(x))
debug_size(x::Observable, level) = nothing# println(" "^level, x.id)

function debug_size(node::Node, level)
    # return println(" "^level, "DOM")
end

function debug_size(x::Vector{T}, level) where {T<:Number}
    printsize(typeof(x), x)
end

function debug_size(x::Union{AbstractArray, Tuple}, level)
    return foreach(x-> debug_size(x, level+1), x)
end

function debug_size(dict::AbstractDict, level)
    if haskey(dict, "__javascript_type__")
        printsize(dict["__javascript_type__"], dict["payload"])
    else
        for (k, v) in dict
            # println(" "^level, k, ":")
            debug_size(v, level + 1)
        end
    end
end

debug_size(jss::JSString, level) = nothing#println(" "^level, "JSCode")

function debug_size(jsc::JSCode, level)
    # println(" "^level, "JSCode")
end

function debug_size(asset::Asset, level)
    # println(" "^level, "Asset")
end
