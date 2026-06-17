using Dates, Test

function last_modified(path::String)
    return Dates.unix2datetime(Base.Filesystem.mtime(path))
end

function needs_bundling(path, bundled)
    !isfile(bundled) && return true
    # If bundled happen after last modification of asset
    return last_modified(path) > last_modified(bundled)
end

path = joinpath(@__DIR__, "..", "js_dependencies")
bundles(x) = (joinpath(path, x), joinpath(path, replace(x, ".js" => ".bundled.js")))
@test !needs_bundling(bundles("Bonito.js")...)
@test !needs_bundling(bundles("Websocket.js")...)
@test !needs_bundling(bundles("nouislider.min.js")...)

# A bundle that cannot be rewritten (read-only package dir, squashfs/DMG app
# bundle) must be trusted even when the packaging step left the source with a
# newer mtime — otherwise every render tries (and fails) to re-bundle, burning
# the full deno timeout per asset.
@testset "shipped read-only bundles are trusted" begin
    mktempdir() do dir
        source  = joinpath(dir, "module.js")
        bundled = joinpath(dir, "module.bundled.js")
        write(bundled, "// bundled")
        sleep(0.01)
        write(source, "// source")   # source mtime > bundled mtime
        @test Bonito.file_writeable(bundled)
        @test Bonito.needs_bundling(source, bundled)
        chmod(bundled, 0o444)
        @test !Bonito.file_writeable(bundled)
        @test !Bonito.needs_bundling(source, bundled)
        chmod(bundled, 0o644)   # so mktempdir can clean up on every OS
    end
end
