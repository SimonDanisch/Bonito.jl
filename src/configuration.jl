function register_type!(condition::Function, ::Type{T}, available_types::Vector{Pair{DataType, Function}}) where T
    index = findfirst(((type, c),)-> type == T, available_types)
    # constructing Pair like this prevents it from getting converted to the abstract Pair{DataType, Function} type
    pair = Pair{DataType, Function}(T, condition)
    if isnothing(index)
        push!(available_types, pair)
    else
        # connections shouldn't be overwritten, but this is handy for development!
        @warn("replacing existing type for $(T)")
        available_types[index] = pair
    end
    return
end

function force_type!(conn, forced_types::Base.RefValue)
    forced_types[] = conn
end

function force_type(f, conn, forced_types::Base.RefValue)
    try
        force_connection!(conn, forced_types)
        f()
    finally
        force_connection!(nothing, forced_types)
    end
end

function default_type(forced::Base.RefValue, available::Vector{Pair{DataType, Function}})
    if !isnothing(forced[])
        return forced[]
    else
        for i in length(available):-1:1 # start from last inserted
            type_or_nothing = available[i][2]()# ::Union{FrontendConnection, AbstractAssetServer, Nothing}
            isnothing(type_or_nothing) || return type_or_nothing
        end
        error("No type found. This can only happen if someone messed with `$(available)`")
    end
end
