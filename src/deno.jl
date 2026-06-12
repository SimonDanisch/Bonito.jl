using Scratch: @get_scratch!

# Poor mans Require.jl for Deno
const DENO_PKG_ID = Base.PkgId(Base.UUID("04572ae6-984a-583e-9378-9577a1c2574d"), "Deno_jll")
try
    # since Deno doesn't seem to work on all platforms we put it in a try catch-.-
    # Note, that it's not required for most use cases
    using Deno_jll
catch e
    @warn "Can't load Deno, which is ok for non dev purposes" exception = e
end
# esbuild is a hard dependency (tiny, supports more platforms than deno):
# deno's bundler needs the exact matching binary, so it should be the
# resolver's job to provide it, not a runtime download
import esbuild_jll

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

# Can we actually write to `path`? `filemode(path) & S_IWUSR` lies on read-only
# filesystems (squashfs/DMG app bundles preserve the writable mode bits from
# build time), so probe by opening for append — EROFS/EACCES surface here
# without touching the file's content or mtime.
function file_writeable(path::String)
    try
        open(identity, path, "a")
        return true
    catch e
        e isa Union{SystemError, Base.IOError} || rethrow()
        return false
    end
end

# The esbuild version deno's bundler insists on (the esbuild stdio protocol
# does an exact version handshake). Keep in sync when bumping the Deno_jll
# compat: `strings $(Deno_jll.deno_path) | grep -oE "esbuild/[0-9.]+"` or just
# run a bundle and watch the npm download.
const DENO_ESBUILD_VERSION = v"0.25.5"

# deno caches the esbuild binary under the name of the npm package it would
# download (@esbuild/{os}-{arch})
function esbuild_cache_name()
    os = Sys.isapple() ? "darwin" : Sys.iswindows() ? "win32" : "linux"
    arch = Sys.ARCH === :aarch64 ? "arm64" : Sys.ARCH === :x86_64 ? "x64" : string(Sys.ARCH)
    return string("esbuild-", os, "-", arch, Sys.iswindows() ? ".exe" : "")
end

"""
DENO_DIR used for bundling: a Bonito-owned scratchspace, pre-seeded with the
esbuild binary from esbuild_jll. Without this, `deno bundle` downloads
esbuild from npm into the user's deno cache on first use - with it, bundling
is hermetic from the jlls (remote js imports are still fetched and cached
here). If esbuild_jll is missing or its version doesn't match what deno
expects, the directory is simply left unseeded and deno falls back to
downloading.
"""
function deno_cache_dir()
    dir = @get_scratch!("deno-cache")
    esbuild_jll.is_available() || return dir
    version = pkgversion(esbuild_jll)
    # strip the jll build number (e.g. 0.25.5+0)
    if VersionNumber(version.major, version.minor, version.patch) == DENO_ESBUILD_VERSION
        target = joinpath(dir, "dl", "esbuild-$(DENO_ESBUILD_VERSION)", esbuild_cache_name())
        if !isfile(target)
            mkpath(dirname(target))
            cp(esbuild_jll.esbuild_path, target)
        end
    else
        # the Project.toml compat pins the exact version, so this only fires
        # when DENO_ESBUILD_VERSION wasn't kept in sync with a Deno_jll bump
        # (or until the matching esbuild_jll is released); deno then falls
        # back to downloading esbuild from npm
        @warn "esbuild_jll $(version) does not match the version deno expects " *
              "($(DENO_ESBUILD_VERSION)) - bundling will download esbuild from npm" maxlog = 1
    end
    return dir
end

function deno_bundle(path_to_js::AbstractString, output_file::String)
    # bundles shipped as part of a package end up as read only
    # So we can't overwrite them
    isfile(output_file) && !file_writeable(output_file) && return false, "Output file is not writeable"
    Deno_jll = Deno()
    # We treat Deno as a development dependency,
    # so if deno isn't loaded, don't bundle!
    isnothing(Deno_jll) && return false, "Deno not loaded"
    exe = Deno_jll.deno()
    stdout = IOBuffer()
    err = IOBuffer()
    proc = try
        # deno 2.4+ bundler (esbuild-based; `deno bundle` was removed in 2.0
        # and came back in 2.4). Still prints the bundle to stdout when no -o
        # is given. --allow-import: our js imports from hosts outside deno's
        # default allowlist (e.g. cdn.esm.sh); --platform browser: these
        # bundles run in the browser, not in deno/node.
        cmd = addenv(`$exe bundle --allow-import --platform browser $(path_to_js)`,
                     "DENO_DIR" => deno_cache_dir())
        # B45: spawn non-blocking (`wait=false`) so the timeout below can guard
        # against a hung deno.
        run(pipeline(cmd; stdout=stdout, stderr=err); wait=false)
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
