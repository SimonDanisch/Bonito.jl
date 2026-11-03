# Poor mans Require.jl for Deno + esbuild.
# Both are only needed for *bundling* JS assets (a dev/CI task), so we load them
# optionally and don't fail if they're unavailable on the current platform.
const DENO_PKG_ID = Base.PkgId(Base.UUID("04572ae6-984a-583e-9378-9577a1c2574d"), "Deno_jll")
const ESBUILD_PKG_ID = Base.PkgId(Base.UUID("26e969d2-927c-5f74-8db2-a5499fed2ef8"), "esbuild_jll")

# Deno's `bundle` command is powered by esbuild. Before running it, Deno looks for
# a prebuilt esbuild binary in its cache and only downloads it from npm (shelling
# out to node) if it's missing. We avoid that runtime download entirely by shipping
# esbuild_jll and dropping its binary into the cache ourselves (`ensure_esbuild!`).
# For Deno to find it, the cache path must use the esbuild version Deno expects
# (`ESBUILD_VERSION` in Deno's `cli/tools/bundle/esbuild.rs`) — we take that version
# straight from the loaded esbuild_jll (`pkgversion`), and the `[compat]` pins keep
# the JLL and Deno on the same esbuild release.

try
    # Deno doesn't ship for all platforms and is only needed for bundling.
    using Deno_jll
catch e
    @warn "Can't load Deno, which is ok for non dev purposes" exception = e
end

try
    # esbuild backs `deno bundle`; same story as Deno, only needed for bundling.
    using esbuild_jll
catch e
    @warn "Can't load esbuild, which is ok for non dev purposes" exception = e
end

function Deno()
    return get(Base.loaded_modules, DENO_PKG_ID, nothing)
end

function Esbuild()
    return get(Base.loaded_modules, ESBUILD_PKG_ID, nothing)
end

# Platform tag esbuild/Deno use for the prebuilt binary, mirroring Deno's
# `esbuild_platform()` in `cli/tools/bundle/esbuild.rs`. Returns nothing on
# unsupported platforms.
function esbuild_platform()
    arch = Sys.ARCH
    if Sys.islinux()
        arch === :x86_64 && return "linux-x64"
        arch === :aarch64 && return "linux-arm64"
    elseif Sys.isapple()
        arch === :x86_64 && return "darwin-x64"
        arch === :aarch64 && return "darwin-arm64"
    elseif Sys.iswindows()
        arch === :x86_64 && return "win32-x64"
        arch === :aarch64 && return "win32-arm64"
    end
    return nothing
end

# A Deno cache dir we fully control, so we know exactly where to place the esbuild
# binary for `deno bundle` to pick up.
deno_dir() = @get_scratch!("deno")

# Make the esbuild_jll binary available to `deno bundle`. Deno offers no flag or
# env var to point at a prebuilt esbuild — it only looks for one at a fixed path in
# its cache ($DENO_DIR/dl/esbuild-<version>/esbuild-<target>) and otherwise
# downloads it from npm via node. So we drop the JLL binary at exactly that path.
# The copy-to-temp-then-rename mirrors what Deno itself does, so a concurrent bundle
# never executes a half-written binary; `cp` preserves the executable mode. Returns
# false (→ no bundling) if esbuild isn't available for this platform.
function ensure_esbuild!(deno_cache::String)
    esbuild = Esbuild()
    isnothing(esbuild) && return false
    target = esbuild_platform()
    isnothing(target) && return false
    # The version Deno looks for == the esbuild release this JLL ships (the [compat]
    # pins keep them equal); `pkgversion` carries a `+0` build tag, so drop it.
    v = pkgversion(esbuild)
    name = "esbuild-$(target)" * (Sys.iswindows() ? ".exe" : "")
    dst = joinpath(deno_cache, "dl", "esbuild-$(v.major).$(v.minor).$(v.patch)", name)
    isfile(dst) && return true
    try
        mkpath(dirname(dst))
        tmp = tempname(dirname(dst))      # unique sibling -> rename stays atomic
        cp(esbuild.esbuild().exec[1], tmp)
        mv(tmp, dst; force=true)
    catch e
        e isa Union{SystemError, Base.IOError} || rethrow()
    end
    return isfile(dst)
end

"""
    deno_bundle(path_to_js, output_file) -> (ok::Bool, message::String)

Bundle the ES6 module at `path_to_js` (and its imports) into `output_file` via
`deno bundle --platform=browser --allow-import`, using the `Deno_jll` /
`esbuild_jll` binaries (see the top of this file for how esbuild is pre-placed so
Deno never downloads it from npm).

Never throws and never blocks indefinitely: on any failure — Deno/esbuild not
loaded, a `deno bundle` error, an unwritable (read-only) `output_file` — it
returns `(false, message)` with a non-empty diagnostic, so callers
([`bundle_inner!`](@ref)) can decide whether to fall back to a cached bundle or
fail loudly. Returns `(true, "")` once `output_file` has been written.
"""
function deno_bundle(path_to_js::AbstractString, output_file::String)
    iswriteable = filemode(output_file) & Base.S_IWUSR != 0
    # bundles shipped as part of a package end up as read only
    # So we can't overwrite them
    isfile(output_file) && !iswriteable && return false, "Output file is not writeable"
    deno = Deno()
    # We treat Deno as a development dependency,
    # so if deno isn't loaded, don't bundle!
    isnothing(deno) && return false, "Deno not loaded"
    cache = deno_dir()
    # Make sure esbuild is in place, so Deno's bundler doesn't fetch it from npm.
    ensure_esbuild!(cache) || return false, "esbuild_jll not loaded/available (required by `deno bundle`)"
    exe = deno.deno()
    out = IOBuffer()
    err = IOBuffer()
    try
        cmd = Cmd(`$exe bundle --platform=browser --allow-import $(path_to_js)`; dir=dirname(path_to_js))
        cmd = addenv(cmd, "DENO_DIR" => cache)
        run(pipeline(cmd; stdout=out, stderr=err))
    catch e
        err_str = String(take!(err))
        return false, err_str
    end
    # Persist the bundle. Writing can fail on a read-only filesystem (a shipped
    # package dir, squashfs mount, DMG app bundle) even though deno itself
    # succeeded — report that as a normal failure so callers can fall back to a
    # cached bundle instead of crashing with an uncaught exception.
    try
        dir = dirname(output_file)
        !isdir(dir) && mkpath(dir)
        write(output_file, seekstart(out))
    catch e
        e isa Union{SystemError, Base.IOError} || rethrow()
        return false, "Failed to write bundle to $(output_file): $(e)"
    end
    return true, ""
end
