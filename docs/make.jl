using JSServe
using Documenter

JSServe.force_asset_server!(JSServe.AssetFolder(joinpath(@__DIR__, "build/")))

ci = get(ENV, "CI", "false") == "true"

makedocs(modules=[JSServe],
         sitename="JSServe",
         format=Documenter.HTML(prettyurls=ci),
         authors="Simon Danisch and other contributors")

if ci
    deploydocs(repo="github.com/SimonDanisch/JSServe.jl.git"; push_preview=true)
end
