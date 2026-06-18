using Bonito
using Documenter

# Bonito's own documentation, built with the Bonito Documenter writer
# (`Bonito.DocumenterBonito`) — a VitePress-styled, fully Bonito-rendered site.
# The previous `Documenter.HTML` based build is kept in `make_documenterhtml.jl.bak`.

ci = get(ENV, "CI", "false") == "true"

home = (
    name = "Bonito",
    text = "Interactive web UIs in pure Julia",
    tagline = "Render HTML from Julia, talk to the browser, and build dashboards, " *
              "apps and docs by freely combining HTML, CSS and JavaScript — no framework lock-in.",
    image = "bonito.svg",
    actions = [
        (text = "Get Started", link = "app.html", theme = "brand"),
        (text = "View on GitHub", link = "https://github.com/SimonDanisch/Bonito.jl", theme = "alt"),
    ],
    features = [
        (title = "Composable components",
         details = "Cards, Grids, Rows and plain HTML widgets you can style and combine freely."),
        (title = "WGLMakie integration",
         details = "High-performance, interactive visualizations that pair perfectly with Bonito."),
        (title = "Any JS library",
         details = "Wrap any CSS/JavaScript library through `Asset` and `js\"...\"`."),
        (title = "Static export",
         details = "Ship dashboards and documentation as standalone static sites with `export_static`."),
    ],
)

makedocs(
    modules = [Bonito],
    sitename = "Bonito",
    authors = "Simon Danisch and other contributors",
    format = Bonito.DocumenterBonito(
        repo = "github.com/SimonDanisch/Bonito.jl",
        devbranch = "master",
        devurl = "dev",
        version = "dev",
        logo = "bonito.svg",
        home = home,
        blog = "blog",
    ),
    pages = [
        "Home" => "index.md",
        "App" => "app.md",
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
        "Handlers" => "handlers.md",
        "Deployment" => "deployment.md",
        "Static Sites" => "static.md",
        "Api" => "api.md",
    ],
)

if ci
    deploydocs(repo = "github.com/SimonDanisch/Bonito.jl.git"; push_preview = true)
end
