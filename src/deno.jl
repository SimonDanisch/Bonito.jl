# Poor mans Require.jl for Deno
const DENO_PKG_ID = Base.PkgId(Base.UUID("04572ae6-984a-583e-9378-9577a1c2574d"), "Deno_jll")

function Deno()
    if haskey(Base.loaded_modules, DENO_PKG_ID)
        return Base.loaded_modules[DENO_PKG_ID]
    else
        return nothing
    end
end

function deno_bundle(path_to_js::String, output_file::String)
    Deno_jll = Deno()
    # We tread Deno as a development dependency,
    # so if deno isn't loaded, don't bundle!
    isnothing(Deno_jll) && return false
    @info("bundlin'")
    Deno_jll.deno() do exe
        stdout = IOBuffer()
        err = IOBuffer()
        try
            run(pipeline(`$exe bundle $(path_to_js)`; stdout=stdout, stderr=err))
        catch e
            write(stderr, seekstart(err))
        end
        write(output_file, seekstart(stdout))
    end
    return true
end
