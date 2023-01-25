using Dashi
using Documenter

ci = get(ENV, "CI", "false") == "true"

makedocs(modules=[Dashi],
         sitename="Dashi",
        format=Documenter.HTML(prettyurls=false),
         authors="Simon Danisch and other contributors")

if ci
    deploydocs(repo="github.com/SimonDanisch/JSServe.jl.git"; push_preview=true)
end
