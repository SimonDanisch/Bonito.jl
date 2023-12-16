# using Bonito, Markdown

function test_handler(session, req)
    global test_observable
    test_observable = Observable(Dict{String, Any}())
    test_session = session

    global s1 = Bonito.Slider(1:100)
    global s2 = Bonito.Slider(1:100)
    b = Bonito.Button("hi"; dataTestId="hi_button")

    clicks = Observable(0)
    on(b) do click
        clicks[] = clicks[] + 1
    end
    clicks_div = DOM.div(clicks, dataTestId="button_clicks")
    t = Bonito.TextField("Write!")

    linkjs(session, s1.index, s2.index)

    onjs(session, s1.value, js"""function (v){
        $(test_observable).notify({onjs: v});
    }""")

    on(t) do value
        test_observable[] = Dict{String, Any}("textfield" => value)
    end

    on(b) do value
        test_observable[] = Dict{String, Any}("button" => value)
    end

    textresult = DOM.div(t.value; dataTestId="text_result")
    sliderresult = DOM.div(s1.value; dataTestId="slider_result")

    number_input = Bonito.NumberInput(66.0)
    number_result = DOM.div(number_input.value, dataTestId="number_result")
    linked_value = DOM.div(s2.value, dataTestId="linked_value")

    dom = md"""
    # IS THIS REAL?

    My first slider: $(s1)

    My second slider: $(s2)

    Test: $(sliderresult)

    The BUTTON: $(b)

    $(clicks_div)

    # Number Input

    $(number_input)

    $(number_result)

    Type something for the list: $(t)

    some list $(textresult)
    $(linked_value)
    """
    return DOM.div(dom)
end

function test_current_session(app)
    dom = children(app.dom)[1]
    @test evaljs(app, js"document.querySelectorAll('button').length") == 1
    @test evaljs(app, js"document.querySelectorAll('input[type=\"range\"]').length") == 2
    @test evaljs(app, js"document.querySelectorAll('button').length") == 1
    @test evaljs(app, js"document.querySelectorAll('input[type=\"range\"]').length") == 2

    @testset "button" begin
        # It's in the dom!
        @test evaljs(app, js"document.querySelectorAll('button').length") == 1
        bquery = query_testid("hi_button")
        # Spam the button press on the JS side a bit, to make sure we're not loosing events!
        for i in 1:100
            val = test_value(app, js"$(bquery).click()")
            @test val["button"] == true
        end
        button = query_testid("button_clicks")
        @test evaljs(app, js"$(button).innerText") == "100"
        button = dom.content[5].content[2]
        @test button.content[] == "hi"
        button.content[] = "new name"
        bquery = query_testid("hi_button")
        @test evaljs(app, js"$(bquery).innerText") == "new name"
        # button press from Julia
        val = test_value(app, ()-> (button.value[] = true))
        @test val["button"] == true
    end

    @testset "textfield" begin
        @test evaljs(app, js"document.querySelectorAll('input[type=\"textfield\"]').length") == 1
        # @test evaljs(app, js"document.querySelector('input[type=\"textfield\"]').value") == "Write!"
        # Spam the button press a bit!
        text_obs = children(dom.content[end].content[2])[1]
        textfield = dom.content[end-1].content[2]
        text_result = query_testid("text_result")
        @test evaljs(app, js"$(text_result).innerText") == "Write!"
        @testset "setting value from js" begin
            for i in 1:10
                str = randstring(10)
                do_input = js"""
                    var tfield = document.querySelector('input[type=\"textfield\"]');
                    tfield.value = $(str);
                    tfield.onchange({srcElement: tfield});
                """
                val = test_value(app, do_input)
                @test val["textfield"] == str
                @test text_obs[] == str
                evaljs(app, js"$(text_result).innerText") == str
                @test textfield[] == str
            end
        end
        @testset "setting value from julia" begin
            for i in 1:10
                str = randstring(10)
                val = test_value(app, ()-> textfield[] = str)
                @test val["textfield"] == str
                @test text_obs[] == str
                evaljs(app, js"$(text_result).innerText") == str
                @test textfield[] == str
            end
        end
    end

    @testset "slider" begin
        # We test with JSCall this time, to test it as well ;)
        slider1 = dom.content[2].content[2]
        slider2 = dom.content[3].content[2]
        slider1_js = js"document.querySelectorAll('input[type=\"range\"]')[0]"
        slider2_js = query_testid("linked_value")
        sliderresult = query_testid("slider_result")

        @testset "set via julia" begin
            for i in 1:2:100
                slider1[] = i
                @test evaljs(app, js"$(slider1_js).value") == "$i"
                # Test linkjs
                @test evaljs(app, js"$(slider2_js).innerText") == "$i"
                @test slider2[] == i
                evaljs(app, js"$(sliderresult).innerText") == "$i"
            end
        end
    end
end

global dom = nothing
inline_display = Bonito.App() do session, req
    global dom = test_handler(session, req)
    return dom
end;
Bonito.CURRENT_SESSION[] = nothing
display(edisplay, inline_display);
app = TestSession(URI("http://localhost:8555/show"),
    Bonito.GLOBAL_SERVER[], edisplay.window, inline_display.session[])
app.dom = dom;
app.initialized = false
wait(app)
Electron.toggle_devtools(app.window)
@testset "electron inline display" begin
    test_current_session(app)
end
close(app)

@testset "Electron standalone" begin
    testsession(test_handler, port=8555) do app
        test_current_session(app)
    end
end

@testset "markdown" begin
    function test_handler(session, req)
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

    testsession(test_handler, port=8555) do app
        id = app.session.id
        markdown_dom = js"document.querySelector('.markdown-body')"
        md_children = js"$(markdown_dom).children"
        @test evaljs(app, js"$(md_children).length") == 23
        @test occursin("This is the first footnote.", evaljs(app, js"$(md_children)[22].innerText"))
        @test evaljs(app, js"$(md_children)[2].children[0].children[0].tagName") == "IMG"
    end
end
