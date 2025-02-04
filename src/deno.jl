# Poor mans Require.jl for Deno
const DENO_PKG_ID = Base.PkgId(Base.UUID("04572ae6-984a-583e-9378-9577a1c2574d"), "Deno_jll")
try
    # since Deno doesn't seem to work on all platforms we put it in a try catch-.-
    # Note, that it's not required for most use cases
    using Deno_jll
catch e
    @warn "Can't load Deno, which is ok for non dev purposes" exception = e
end

function Deno()
    if haskey(Base.loaded_modules, DENO_PKG_ID)
        return Base.loaded_modules[DENO_PKG_ID]
    else
        return nothing
    end
end

function deno_bundle(path_to_js::AbstractString, output_file::String)
    iswriteable = filemode(output_file) & Base.S_IWUSR != 0
    # bundles shipped as part of a package end up as read only
    # So we can't overwrite them
    isfile(output_file) && !iswriteable && return false
    Deno_jll = Deno()
    # We treat Deno as a development dependency,
    # so if deno isn't loaded, don't bundle!
    isnothing(Deno_jll) && return false, "Deno not loaded"
    exe = Deno_jll.deno()
    stdout = IOBuffer()
    err = IOBuffer()
    try
        run(pipeline(`$exe bundle $(path_to_js)`; stdout=stdout, stderr=err))
    catch e
        err_str = String(take!(err))
        return false, err_str
    end
    write(output_file, seekstart(stdout))
    return true, ""
end
