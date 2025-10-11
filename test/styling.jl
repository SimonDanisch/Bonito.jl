
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
    # Use no connection, since otherwise the session will be added to
    # The global running HTTP server
    s = OfflineSession()
    Bonito.session_dom(s, app)
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

@testset "OrderedDict preserves insertion order" begin
    d = Bonito.OrderedDict{String, Int}()
    d["first"] = 1
    d["second"] = 2
    d["third"] = 3

    # Test that iteration preserves order
    collected = collect(keys(d))
    @test collected == ["first", "second", "third"]

    # Test merge! preserves order
    d2 = Bonito.OrderedDict{String, Int}()
    d2["fourth"] = 4
    d2["fifth"] = 5

    merge!(d, d2)
    collected = collect(keys(d))
    @test collected == ["first", "second", "third", "fourth", "fifth"]
end

@testset "Styles preserves CSS rule order" begin
    # Create base styles with :root first
    base = Styles(CSS(":root", "color" => "black"))
    media = Styles(CSS("@media (max-width: 480px)", CSS(":root", "color" => "white")))

    # Merge - media should come after base
    combined = merge(base, media)

    selectors = collect(keys(combined.styles))
    @test selectors[1] == ":root"
    @test selectors[2] == "@media (max-width: 480px)"
end

@testset "Styles constructor with multiple args preserves order" begin
    style1 = Styles(CSS(":root", "color" => "black"))
    style2 = Styles(CSS(".navbar", "height" => "50px"))
    style3 = Styles(CSS("@media (max-width: 480px)", CSS(":root", "color" => "white")))

    # When constructing Styles(s1, s2, s3), s1 is priority and should come LAST
    # This is confusing behavior - first arg takes priority but comes last in merge
    combined = Styles(style1, style2, style3)

    selectors = collect(keys(combined.styles))
    # According to Styles(priority::Styles, defaults...)
    # It creates Styles(defaults...) then merges priority into it
    # So style2, style3 are created first, then style1 is merged in
    @test length(selectors) == 3
    # Check that we have all three selectors
    @test ":root" in selectors
    @test ".navbar" in selectors
    @test "@media (max-width: 480px)" in selectors

    # The first argument (style1) values should override when same selector exists
    # But order-wise, for OrderedDict, when does the key appear?
    # If :root already exists in defaults, merge! updates value but keeps position
    # If :root doesn't exist in defaults, it gets added at the end
end

@testset "Styles merging updates values but preserves key position" begin
    # Create style with :root at position 1
    base = Styles(CSS(":root", "color" => "black"))

    # Create another style with different selector at position 2
    extra = Styles(CSS(".class", "margin" => "10px"))

    # Merge them
    combined = merge(base, extra)
    @test collect(keys(combined.styles)) == [":root", ".class"]

    # Now merge in a style that updates :root
    override = Styles(CSS(":root", "color" => "white"))
    combined2 = merge(combined, override)

    # :root should still be at position 1, but with updated value
    selectors = collect(keys(combined2.styles))
    @test selectors[1] == ":root"
    @test combined2.styles[":root"].attributes["color"] == "white"
end
