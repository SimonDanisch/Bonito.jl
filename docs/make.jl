using JSServe
using Documenter

ci = get(ENV, "CI", "false") == "true"

makedocs(
    modules=[JSServe],
    sitename="JSServe",
    format=Documenter.HTML(prettyurls=false),
    authors="Simon Danisch and other contributors",
    pages = [
        "Home" => "index.md",
        "Deployment" => "deployment.md",
        "Extending" => "extending.md",
        "Plotting" => "plotting.md",
        "Widgets" => "widgets.md",
        "Assets" => "assets.md",
        "Api" => "api.md",
    ]
)

if ci
    deploydocs(repo="github.com/SimonDanisch/JSServe.jl.git"; push_preview=true)
end
