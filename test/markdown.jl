function test_handler(session, req)
    global test_observable
    test_observable = Observable(Dict{String, Any}())
    test_session = session

    s1 = JSServe.Slider(1:100)
    s2 = JSServe.Slider(1:100)
    b = JSServe.Button("hi"; dataTestId="hi_button")

    clicks = Observable(0)
    on(b) do click
        clicks[] = clicks[] + 1
    end
    clicks_div = DOM.div(clicks, dataTestId="button_clicks")
    t = JSServe.TextField("Write!")

    linkjs(session, s1.value, s2.value)

    onjs(session, s1.value, js"""function (v){
        var updated = JSServe.update_obs($(test_observable), {onjs: v});
        console.log(updated);
    }""")

    on(t) do value
        test_observable[] = Dict{String, Any}("textfield" => value)
    end

    on(b) do value
        test_observable[] = Dict{String, Any}("button" => value)
    end

    textresult = DOM.div(t.value; dataTestId="text_result")
    sliderresult = DOM.div(s1.value; dataTestId="slider_result")

    number_input = JSServe.NumberInput(66.0)
    number_result = DOM.div(number_input.value, dataTestId="number_result")

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
                    tfield.onchange();
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
        slider2_js = js"document.querySelectorAll('input[type=\"range\"]')[1]"
        sliderresult = query_testid("slider_result")

        @testset "set via julia" begin
            for i in 1:2:100
                slider1[] = i
                @test evaljs(app, js"$(slider1_js).value") == "$i"
                # Test linkjs
                @test evaljs(app, js"$(slider2_js).value") == "$i"
                @test slider2[] == i
                evaljs(app, js"$(sliderresult).innerText") == "$i"
            end
        end
    end
end

global test_session = nothing
global dom = nothing
inline_display = JSServe.App() do session, req
    global test_session = session
    global dom = test_handler(session, req)
    return DOM.div(JSTest, dom)
end;
electron_disp = electrondisplay(inline_display);
app = TestSession(URI("http://localhost:8555/show"),
                  JSServe.GLOBAL_SERVER[], electron_disp, test_session)
app.dom = dom

@testset "electron inline display" begin
    test_current_session(app)
end
close(app)

@testset "webio mime" begin
    ENV["JULIA_WEBIO_BASEURL"] = "https://google.de/"
    JSServe.__init__()
    @test JSServe.JSSERVE_CONFIGURATION.external_url[] == "https://google.de"
    @test JSServe.JSSERVE_CONFIGURATION.content_delivery_url[] == "https://google.de"
    html_webio = sprint(io-> show(io, MIME"application/vnd.jsserve.application+html"(), inline_display))
    #@test occursin("proxy_url = 'https://google.de';", html_webio)
    # @test JSServe.url("/test") == "https://google.de/test"
    JSServe.JSSERVE_CONFIGURATION.external_url[] = ""
    JSServe.JSSERVE_CONFIGURATION.content_delivery_url[] = ""
    # @test JSServe.url("/test") == "/test" # back to relative urls
    html_webio = sprint(io-> show(io, MIME"application/vnd.jsserve.application+html"(), inline_display))
    # We open the display server with the above TestSession
    # TODO electrontests should do this!
    check_and_close_display()
end

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

        [![Build Status](https://travis-ci.com/SimonDanisch/JSServe.jl.svg?branch=master)](https://travis-ci.com/SimonDanisch/JSServe.jl)

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
        return DOM.div(JSServe.MarkdownCSS, dom)
    end

    testsession(test_handler, port=8555) do app
        # Lets not be too porcelainy about this ...
        md_js_dom = js"document.getElementById('application-dom').children[0]"
        @test evaljs(app, js"$(md_js_dom).children.length") == 1
        md_children = js"$(md_js_dom).children[0].children[0].children"
        @test evaljs(app, js"$(md_children).length") == 23
        @test occursin("This is the first footnote.", evaljs(app, js"$(md_children)[22].innerText"))
        @test evaljs(app, js"$(md_children)[2].children[0].children[0].tagName") == "IMG"
    end
end

@testset "range slider" begin
    function test_handler(session, req)
        rslider = JSServe.RangeSlider(1:100; value=[10, 80])
        start = map(first, rslider)
        stop = map(last, rslider)
        return DOM.div(rslider, start, stop, id="rslider")
    end
    testsession(test_handler, port=8555) do app
        # Lets not be too porcelainy about this ...
        rslider = getfield(app.dom, :children)[1]
        @test rslider[] == [10, 80]
        rslider_html = js"document.getElementById('rslider')"
        @test evaljs(app, js"$(rslider_html).children.length") == 3
        @test evaljs(app, js"$(rslider_html).children[1].innerText") == "10"
        @test evaljs(app, js"$(rslider_html).children[2].innerText") == "80"
        rslider[] = [20, 70]
    end
end
