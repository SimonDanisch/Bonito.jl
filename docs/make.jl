using Deno_jll, JSServe
using Documenter

ci = get(ENV, "CI", "false") == "true"

makedocs(
    modules=[JSServe],
    sitename="JSServe",
    clean=false,
    format=Documenter.HTML(prettyurls=false),
    authors="Simon Danisch and other contributors",
    pages=[
        "Home" => "index.md",
        "Plotting" => "plotting.md",
        "Widgets" => "widgets.md",
        "Animation" => "animation.md",
        "Deployment" => "deployment.md",
        "Assets" => "assets.md",
        "Extending" => "extending.md",
        "Api" => "api.md",
    ]
)

if ci
    deploydocs(repo="github.com/SimonDanisch/JSServe.jl.git"; push_preview=true)
end
