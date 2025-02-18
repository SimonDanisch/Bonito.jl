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
