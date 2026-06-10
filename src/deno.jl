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

# Hard cap on a single `deno bundle` invocation. A hung deno (network fetch of
# a remote import that never returns, etc.) would otherwise pin the calling
# task forever (B45).
const DENO_BUNDLE_TIMEOUT = 120.0

function deno_bundle(path_to_js::AbstractString, output_file::String)
    iswriteable = filemode(output_file) & Base.S_IWUSR != 0
    # bundles shipped as part of a package end up as read only
    # So we can't overwrite them
    isfile(output_file) && !iswriteable && return false, "Output file is not writeable"
    Deno_jll = Deno()
    # We treat Deno as a development dependency,
    # so if deno isn't loaded, don't bundle!
    isnothing(Deno_jll) && return false, "Deno not loaded"
    exe = Deno_jll.deno()
    stdout = IOBuffer()
    err = IOBuffer()
    proc = try
        run(pipeline(`$exe bundle $(path_to_js)`; stdout=stdout, stderr=err); wait=false)
    catch e
        # B45: when stderr is empty, the discarded Julia exception was the only
        # diagnostic — include it so the failure isn't reported as "".
        err_str = String(take!(err))
        isempty(err_str) && (err_str = sprint(showerror, e))
        return false, err_str
    end
    # B45: enforce a timeout. `timedwait` polls without blocking the scheduler.
    finished = timedwait(() -> process_exited(proc), DENO_BUNDLE_TIMEOUT; pollint=0.1)
    if finished !== :ok
        kill(proc)
        return false, "deno bundle timed out after $(DENO_BUNDLE_TIMEOUT)s for $(path_to_js)"
    end
    if !success(proc)
        err_str = String(take!(err))
        isempty(err_str) && (err_str = "deno bundle exited with code $(proc.exitcode)")
        return false, err_str
    end
    dir = dirname(output_file)
    !isdir(dir) && mkpath(dir)
    write(output_file, seekstart(stdout))
    return true, ""
end
