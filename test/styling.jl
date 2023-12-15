
@testset "style de-duplication" begin
    x = Styles(Styles(), "background-color" => "gray", "color" => "white")
    y = Styles(Styles(), "background-color" => "gray", "color" => "white")
    @test Set(values(x.styles)) == Set(values(y.styles))

    x = Styles("background-color" => "gray", "color" => "white")
    y = Styles("background-color" => "gray", "color" => "white")
    @test Set(values(x.styles)) == Set(values(y.styles))

    x = CSS("background-color" => "gray", "color" => "white")
    y = CSS("background-color" => "gray", "color" => "white")
    @test Set(values(x.attributes)) == Set(values(y.attributes))


    x = CSS("background-color" => "gray", "color" => 1)
    y = CSS("background-color" => "gray", "color" => "1")
    @test Set(values(x.attributes)) == Set(values(y.attributes))
end

@testset "deduplication in rendered dom" begin
    app = App() do
        base = Styles("border" => "1px solid black", "padding" => "5px")
        days = map(1:31) do day
            DOM.div(day; style=Styles(base, "background-color" => "gray", "color" => "black"))
        end
        return DOM.div(days...)
    end
    s = Session()
    JSServe.session_dom(s, app)
    all_css = Set([css for (n, set) in s.stylesheets for css in set])
    @test length(all_css) == 1
    css = CSS(
        "border" => "1px solid black",
        "padding" => "5px",
        "background-color" => "gray",
        "color" => "black",
    )
    @test first(all_css) == css
end

@testset "merge & hash" begin
    css1 = CSS(
        "border" => "1px solid black",
        "padding" => "5px",
        "background-color" => "gray",
        "color" => "black",
    )
    css2 = CSS(
        "border" => "1px solid black",
        "padding" => "5px",
        "background-color" => "gray",
        "color" => "black",
    )
    css3 = merge(css1, css2)

    @test css1 == css2
    @test css3 == css2

    @test hash(css1) == hash(css2)
    @test hash(css3) == hash(css2)
end
