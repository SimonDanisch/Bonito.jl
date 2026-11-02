using Bonito, Documenter, Test

function favicon_docs_fixture(root; assets = String[])
    src = joinpath(root, "src")
    mkpath(joinpath(src, "nested"))
    mkpath(joinpath(src, "assets"))
    mkpath(joinpath(root, "blog", "first-post"))
    write(joinpath(src, "index.md"), "# Welcome\n\nAn example home page.\n")
    write(joinpath(src, "nested", "guide.md"), "# Guide\n\nA nested page.\n")
    write(joinpath(root, "blog", "first-post", "post.md"), "# First post\n\nA blog post.\n")
    cp(joinpath(@__DIR__, "..", "docs", "src", "assets", "favicon.ico"), joinpath(src, "assets", "favicon.ico"))
    write(joinpath(src, "assets", "custom.css"), "body { --favicon-test: 1; }")
    write(joinpath(src, "assets", "custom.js"), "window.faviconFixture = true;")
    Documenter.makedocs(;
        root, sitename = "Favicon test", remotes = nothing, doctest = false,
        format = Bonito.DocumenterBonito(; assets, home = (name = "Home",), blog = "blog"),
        pages = ["Home" => "index.md", "Guide" => "nested/guide.md"],
    )
    return joinpath(root, "build")
end

@testset "Documenter head assets" begin
    @test isempty(Bonito.DocumenterBonito().assets)
    mktempdir() do root
        build = favicon_docs_fixture(
            root; assets = [
                "assets/favicon.ico", "assets/custom.css", "assets/custom.js",
                Documenter.asset("https://example.org/remote.js"; attributes = Dict(:defer => "")),
            ]
        )
        @test read(joinpath(build, "assets", "favicon.ico")) == read(joinpath(@__DIR__, "..", "docs", "src", "assets", "favicon.ico"))
        for page in ("index.html", "nested/guide.html", "blog.html", "first-post.html")
            html = read(joinpath(build, page), String)
            head = match(r"<head\b[^>]*>(.*?)</head>"s, html).captures[1]
            prefix = startswith(page, "nested/") ? "../" : ""
            @test occursin("href=\"$(prefix)assets/favicon.ico\"", head)
            @test occursin("rel=\"icon\"", head)
            @test occursin("href=\"$(prefix)assets/custom.css\"", head)
            @test occursin("src=\"$(prefix)assets/custom.js\"", head)
            @test occursin("src=\"https://example.org/remote.js\"", head)
            @test occursin("defer", head)
            @test !occursin("&lt;link", head)
        end
    end
    mktempdir() do root
        build = favicon_docs_fixture(root)
        html = read(joinpath(build, "index.html"), String)
        @test !occursin("rel=\"icon\"", html)
        @test !occursin("href=\"\"", html)
    end
end
