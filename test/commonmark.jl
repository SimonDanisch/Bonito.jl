# CommonMark integration tests (no Electron required)
using CommonMark

@testset "CommonMark" begin
    @testset "bonito_parser" begin
        parser = Bonito.bonito_parser()
        @test parser isa CommonMark.Parser

        # Parse and return AST
        ast = Bonito.bonito_parser("# Hello")
        @test ast isa CommonMark.Node
        @test ast.t isa CommonMark.Document
    end

    @testset "commonmark_to_dom basics" begin
        # Headings
        dom = Bonito.commonmark_to_dom(Bonito.bonito_parser("# H1\n## H2\n### H3"))
        @test dom isa Bonito.CommonMarkDOM
        html = sprint(show, dom)
        @test occursin("<h1", html)
        @test occursin("<h2", html)
        @test occursin("<h3", html)
        @test occursin("H1", html)

        # Paragraphs, bold, italic
        dom = Bonito.commonmark_to_dom(Bonito.bonito_parser("Some **bold** and *italic* text."))
        html = sprint(show, dom)
        @test occursin("<strong>", html)
        @test occursin("<em>", html)
        @test occursin("bold", html)
        @test occursin("italic", html)

        # Inline code
        dom = Bonito.commonmark_to_dom(Bonito.bonito_parser("Use `inline code` here."))
        html = sprint(show, dom)
        @test occursin("<code>", html)
        @test occursin("inline code", html)
    end

    @testset "commonmark_to_dom code blocks" begin
        dom = Bonito.commonmark_to_dom(Bonito.bonito_parser("""
```julia
function foo(x)
    return x + 1
end
```
"""))
        html = sprint(show, dom)
        @test occursin("<pre>", html)
        @test occursin("<code", html)
        @test occursin("language-julia", html)
        @test occursin("function foo", html)
    end

    @testset "commonmark_to_dom links and images" begin
        dom = Bonito.commonmark_to_dom(Bonito.bonito_parser("[Click](https://example.com)"))
        html = sprint(show, dom)
        @test occursin("<a", html)
        @test occursin("href", html)
        @test occursin("https://example.com", html)
        @test occursin("Click", html)

        dom = Bonito.commonmark_to_dom(Bonito.bonito_parser("![Alt](image.png)"))
        html = sprint(show, dom)
        @test occursin("<img", html)
        @test occursin("src", html)
        @test occursin("image.png", html)
    end

    @testset "commonmark_to_dom lists" begin
        # Ordered list
        dom = Bonito.commonmark_to_dom(Bonito.bonito_parser("1. First\n2. Second\n"))
        html = sprint(show, dom)
        @test occursin("<ol>", html)
        @test occursin("<li>", html)
        @test occursin("First", html)

        # Unordered list
        dom = Bonito.commonmark_to_dom(Bonito.bonito_parser("- A\n- B\n"))
        html = sprint(show, dom)
        @test occursin("<ul>", html)
        @test occursin("<li>", html)
    end

    @testset "commonmark_to_dom tables" begin
        dom = Bonito.commonmark_to_dom(Bonito.bonito_parser("""
| Name | Age |
|------|-----|
| Alice | 30 |
| Bob | 25 |
"""))
        html = sprint(show, dom)
        @test occursin("<table>", html)
        @test occursin("<thead>", html)
        @test occursin("<tbody>", html)
        @test occursin("<th", html)
        @test occursin("<td", html)
        @test occursin("Alice", html)
        # Check alignment is via style, not raw pairs
        @test !occursin("=&gt;", html)
        @test occursin("text-align", html) || !occursin("align", html)
    end

    @testset "commonmark_to_dom blockquotes and rules" begin
        dom = Bonito.commonmark_to_dom(Bonito.bonito_parser("> A blockquote\n"))
        html = sprint(show, dom)
        @test occursin("<blockquote>", html)

        dom = Bonito.commonmark_to_dom(Bonito.bonito_parser("---\n"))
        html = sprint(show, dom)
        @test occursin("<hr", html)
    end

    @testset "commonmark_to_dom inline HTML" begin
        # This is a key feature of the CommonMark migration
        dom = Bonito.commonmark_to_dom(Bonito.bonito_parser(
            """Some <span style="color:red">red</span> text."""
        ))
        html = sprint(show, dom)
        @test occursin("<span", html)
        @test occursin("color:red", html)
        @test occursin("red", html)

        # HTML blocks
        dom = Bonito.commonmark_to_dom(Bonito.bonito_parser("""
<div class="custom">
  <p>Block HTML</p>
</div>
"""))
        html = sprint(show, dom)
        @test occursin("custom", html)
        @test occursin("Block HTML", html)
    end

    @testset "commonmark_to_dom math" begin
        # Inline math -> KaTeX
        dom = Bonito.commonmark_to_dom(Bonito.bonito_parser(raw"Inline $x^2$ here."))
        html = sprint(show, dom)
        @test occursin("KaTeX", html)
        @test occursin("x^2", html)

        # Display math -> KaTeX with display=true
        dom = Bonito.commonmark_to_dom(Bonito.bonito_parser(raw"""
$$
\sum_{i=1}^{n} i
$$
"""))
        html = sprint(show, dom)
        @test occursin("KaTeX", html)
        @test occursin("true", html)  # display=true
    end

    @testset "commonmark_to_dom strikethrough" begin
        dom = Bonito.commonmark_to_dom(Bonito.bonito_parser("This is ~~deleted~~ text."))
        html = sprint(show, dom)
        @test occursin("<s>", html)
        @test occursin("deleted", html)
    end

    @testset "commonmark_to_dom footnotes" begin
        dom = Bonito.commonmark_to_dom(Bonito.bonito_parser(
            "Text[^1].\n\n[^1]: Footnote content."
        ))
        html = sprint(show, dom)
        @test occursin("footnote", html)
        @test occursin("Footnote content", html)
    end

    @testset "commonmark_to_dom admonitions" begin
        dom = Bonito.commonmark_to_dom(Bonito.bonito_parser("""
!!! note "Title"
    Body text.
"""))
        html = sprint(show, dom)
        @test occursin("admonition", html)
        @test occursin("note", html)
        @test occursin("Title", html)
        @test occursin("Body text", html)
    end

    @testset "commonmark_to_dom replacements" begin
        # Test that replacement functions are called for matching node types
        replacements = Dict{Any, Function}(
            CommonMark.CodeBlock => (node) -> begin
                if node.t.info == "julia"
                    return DOM.div("REPLACED"; class="custom")
                end
                return nothing  # default rendering
            end,
        )

        dom = Bonito.commonmark_to_dom(Bonito.bonito_parser("""
```julia
x = 1
```

```python
y = 2
```
"""); replacements=replacements)
        html = sprint(show, dom)
        @test occursin("REPLACED", html)
        @test occursin("custom", html)
        # Python block should use default rendering
        @test occursin("language-python", html)
    end

    @testset "string_to_markdown routing" begin
        # With CommonMark replacement keys -> CommonMark path
        result = Bonito.string_to_markdown("# Hello", Dict{Any,Function}(
            CommonMark.CodeBlock => (n) -> nothing
        ))
        @test result isa Bonito.CommonMarkDOM

        # Without CommonMark keys -> stdlib Markdown path
        result = Bonito.string_to_markdown("# Hello")
        @test result isa Markdown.MD

        # With stdlib keys -> stdlib Markdown path
        result = Bonito.string_to_markdown("# Hello", Dict{Any,Function}(
            Markdown.Code => (n) -> nothing
        ))
        @test result isa Markdown.MD
    end

    @testset "walk_dom CommonMarkDOM" begin
        dom = Bonito.commonmark_to_dom(Bonito.bonito_parser("**hello** world"))
        types = Type[]
        Bonito.walk_dom(dom) do x
            push!(types, typeof(x))
        end
        @test !isempty(types)
        @test any(t -> t == String, types)
    end

    @testset "nested structures" begin
        # Nested list with inline formatting
        dom = Bonito.commonmark_to_dom(Bonito.bonito_parser("""
- Item **bold**
- Item *italic*
  - Nested item
"""))
        html = sprint(show, dom)
        @test occursin("<ul>", html)
        @test occursin("<strong>", html)
        @test occursin("<em>", html)
        @test occursin("Nested item", html)

        # Blockquote containing code block
        dom = Bonito.commonmark_to_dom(Bonito.bonito_parser("""
> Some quote with `inline code`.
"""))
        html = sprint(show, dom)
        @test occursin("<blockquote>", html)
        @test occursin("<code>", html)
        @test occursin("inline code", html)
    end

    @testset "edge cases" begin
        # Empty document
        dom = Bonito.commonmark_to_dom(Bonito.bonito_parser(""))
        html = sprint(show, dom)
        @test dom isa Bonito.CommonMarkDOM

        # Heading with inline code
        dom = Bonito.commonmark_to_dom(Bonito.bonito_parser("## Using `foo()` function"))
        html = sprint(show, dom)
        @test occursin("<h2", html)
        @test occursin("<code>", html)
        @test occursin("foo", html)

        # Multiple paragraphs
        dom = Bonito.commonmark_to_dom(Bonito.bonito_parser("First paragraph.\n\nSecond paragraph."))
        html = sprint(show, dom)
        @test occursin("First paragraph", html)
        @test occursin("Second paragraph", html)

        # Video detection (image with video extension)
        dom = Bonito.commonmark_to_dom(Bonito.bonito_parser("![video](demo.mp4)"))
        html = sprint(show, dom)
        @test occursin("demo.mp4", html)
    end

    @testset "walk_dom visits all node types" begin
        dom = Bonito.commonmark_to_dom(Bonito.bonito_parser("""
# Title

Paragraph with **bold** and *italic*.

```julia
code
```
"""))
        visited = Any[]
        Bonito.walk_dom(dom) do x
            push!(visited, x)
        end
        @test length(visited) > 5
        # Should visit strings
        @test any(x -> x isa String, visited)
    end

    @testset "backward compatibility" begin
        # stdlib Markdown rendering still works
        md = Markdown.parse("# Hello **world**")
        session = Bonito.Session()
        rendered = Bonito.jsrender(session, md)
        @test rendered isa Hyperscript.Node{Hyperscript.HTMLSVG}

        # md"" string macro still works
        dom = md"**bold** text"
        @test dom isa Markdown.MD
        rendered = Bonito.jsrender(session, dom)
        @test rendered isa Hyperscript.Node{Hyperscript.HTMLSVG}
    end
end
