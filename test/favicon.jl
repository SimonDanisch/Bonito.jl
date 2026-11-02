using Bonito, Test

@testset "App favicon" begin
    icon = Asset(joinpath(@__DIR__, "..", "docs", "src", "assets", "favicon.ico"))
    for content in (DOM.div("App"), DOM.html(DOM.head(DOM.title("Custom")), DOM.body("App")))
        app = App(content; favicon = icon)
        io = IOBuffer()
        Bonito.export_static(io, app; asset_server = Bonito.NoServer(), connection = Bonito.NoConnection())
        html = String(take!(io))
        head = match(r"<head\b[^>]*>(.*?)</head>"s, html).captures[1]
        @test occursin("rel=\"icon\"", head)
        @test occursin(Bonito.url(Bonito.NoServer(), icon), head)
        @test length(collect(eachmatch(r"rel=\"icon\"", html))) == 1
    end

    @test App(nothing).favicon === nothing
    @test App(nothing; favicon = "https://example.org/icon.png").favicon isa Asset
    io = IOBuffer()
    Bonito.export_static(io, App(DOM.div("Default")); asset_server = Bonito.NoServer(), connection = Bonito.NoConnection())
    @test !occursin("rel=\"icon\"", String(take!(io)))

    parent = Bonito.Session(Bonito.NoConnection(); asset_server = Bonito.NoServer())
    child = Bonito.Session(parent)
    try
        dom = Bonito.session_dom(child, App(DOM.div("Embedded"); favicon = icon))
        @test !occursin("rel=\"icon\"", sprint(show, MIME"text/html"(), dom))
    finally
        close(parent)
    end
end
