# markdown_test_handler, test_current_session defined in test_helpers.jl

global dom = nothing
inline_display = Bonito.App() do session, req
    global dom = markdown_test_handler(session, req)
    return dom
end;
Bonito.CURRENT_SESSION[] = nothing
display(edisplay, inline_display);
app = TestSession(URI("http://localhost:8555/show"))
app.server = Bonito.GLOBAL_SERVER[]
app.window = edisplay.window
app.session = inline_display.session[]
app.dom = dom;
app.initialized = false
wait(app)
@testset "electron inline display" begin
    test_current_session(app)
end
close(app)

@testset "Electron standalone" begin
    testsession(markdown_test_handler, port=8555) do app
        test_current_session(app)
    end
end

@testset "markdown" begin
    function md_only_handler(session, req)
        global dom, test_session, test_observable
        test_session = session
        dom = md"""
        # More MD

        [Github-flavored Markdown info page](http://github.github.com/github-flavored-markdown/)

        [![Build Status](https://travis-ci.com/SimonDanisch/Bonito.jl.svg?branch=master)](https://travis-ci.com/SimonDanisch/Bonito.jl)

        Lalala
        ======

        Alt-H2
        ------

        Emphasis, aka italics, with *asterisks* or _underscores_.

        Strong emphasis, aka bold, with **asterisks** or __underscores__.

        Combined emphasis with **asterisks and _underscores_**.

        Strikethrough uses two tildes. ~~Scratch this.~~

        1. First ordered list item
        2. Another item
            * Unordered sub-list.
        1. Actual numbers don't matter, just that it's a number
            1. Ordered sub-list
        4. And another item.

        * Unordered list can use asterisks
        - Or minuses
        + Or pluses

        Inline `code` has `back-ticks around` it.

        ```julia
        test("haha")
        ```

        | Tables        | Are           | Cool  |
        | ------------- |:-------------:| -----:|
        | col 3 is      | right-aligned | $1600 |
        | col 2 is      | centered      |   $12 |
        | zebra stripes | are neat      |    $1 |

        > Blockquotes are very handy in email to emulate reply text.
        > This line is part of the same quote.

        Three or more...

        ---

        Hyphens[^1]

        ***

        Asterisks

        ___

        Underscores

        [^1]: This is the first footnote.
        """
        return DOM.div(Bonito.MarkdownCSS, dom)
    end

    testsession(md_only_handler, port=8555) do app
        id = app.session.id
        markdown_dom = js"document.querySelector('.markdown-body')"
        md_children = js"$(markdown_dom).children"
        @test evaljs(app, js"$(md_children).length") == 23
        @test occursin("This is the first footnote.", evaljs(app, js"$(md_children)[22].innerText"))
        @test evaljs(app, js"$(md_children)[2].children[0].children[0].tagName") == "IMG"
    end
end
