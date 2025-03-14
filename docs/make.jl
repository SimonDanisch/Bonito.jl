using Deno_jll, Bonito
using Documenter
using DocumenterVitepress

ci = get(ENV, "CI", "false") == "true"
makedocs(
    modules=[Bonito],
    sitename="Bonito",
    clean=false,
    # format=Documenter.HTML(prettyurls=false, size_threshold=300000),
    format=DocumenterVitepress.MarkdownVitepress(
        repo = "github.com/SimonDanisch/Bonito.jl",
        devbranch = "master",
        devurl = "dev";
    ),
    authors="Simon Danisch and other contributors",
    warnonly=true,
    pages=[
        "Home" => "index.md",
        "Components" => [
            "Styling" => "styling.md",
            "Components" => "components.md",
            "Layouting" => "layouting.md",
            "Widgets" => "widgets.md",
            "Interactions" => "interactions.md",
        ],
        "Examples" => [
            "Plotting" => "plotting.md",
            "Wrapping JS libraries" => "javascript-libraries.md",
            "Assets" => "assets.md",
            "Extending" => "extending.md",
        ],
        "Deployment" => "deployment.md",
        "Static Sites" => "static.md",
        "Api" => "api.md",
    ]
)

if ci
    deploydocs(repo="github.com/SimonDanisch/Bonito.jl.git"; push_preview=true)
end
