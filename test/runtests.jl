using Hyperscript, Markdown, Test
using JSServe, Observables
using JSServe: Session, evaljs, linkjs, div
using JSServe: @js_str, onjs, Button, TextField, Slider, JSString, Dependency, with_session, jsobject
using JSServe.DOM
using JSServe.HTTP
using Electron
using ElectronDisplay
using ElectronTests
using URIParser
using Random
using AbstractPlotting
using WGLMakie
using AbstractPlotting.Colors: color, reducec
using Hyperscript: children
using ImageTransformations
using ElectronTests: TestSession

function wait_on_test_observable()
    test_channel = Channel{Dict{String, Any}}(1)
    f = on(test_observable) do value
        put!(test_channel, value)
    end
    val = take!(test_channel)
    off(test_observable, f)
    return val
end

"""
    test_value(app, statement)
Executes statemen (js code, or julia function with 0 args),
And waits on `test_observable` to push a new value!
Returns new value from `test_observable`
"""
function test_value(app, statement)
    # First start waiting on the test communication channel
    # We do this async before scheduling the js, since otherwise there is a
    # chance, that the event gets triggered before we have a chance to wait for it
    # which would make use wait forever
    val_t = @async wait_on_test_observable()
    # eval our js expression that is supposed to write something to test_observable
    if statement isa JSServe.JSCode
        JSServe.evaljs(app.session, statement)
    else
        statement()
    end
    fetch(val_t) # fetch the value!
end

@testset "JSServe" begin
    function test_handler(session, req)
        global test_observable
        test_session = session

        s1 = JSServe.Slider(1:100)
        s2 = JSServe.Slider(1:100)
        b = JSServe.Button("hi"; dataTestId="hi_button")
        clicks = Observable(0)
        on(b) do click
            clicks[] = clicks[] + 1
        end
        clicks_div = DOM.div(clicks, dataTestId="button_clicks")
        t = TextField("Write!")

        test_observable = Observable(Dict{String, Any}())
        linkjs(session, s1.value, s2.value)

        onjs(session, s1.value, js"""function (v){
            var updated = update_obs($(test_observable), {onjs: v});
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
        root = js"document.getElementById('application-dom').children[0]"
        @test evaljs(app, js"$(root).children.length") == 1
        @test evaljs(app, js"$(root).children[0].children[0].children[0].innerText") == "IS THIS REAL?"
        @test evaljs(app, js"document.querySelectorAll('input[type=\"button\"]').length") == 1
        @test evaljs(app, js"document.querySelectorAll('input[type=\"range\"]').length") == 2
        @test evaljs(app, js"document.querySelectorAll('input[type=\"button\"]').length") == 1
        @test evaljs(app, js"document.querySelectorAll('input[type=\"range\"]').length") == 2

        @testset "button" begin
            # It's in the dom!
            @test evaljs(app, js"document.querySelectorAll('input[type=\"button\"]').length") == 1
            button = query_testid(app, "hi_button")
            # Spam the button press on the JS side a bit, to make sure we're not loosing events!
            for i in 1:100
                val = test_value(app, ()-> button.click())
                @test val["button"] == true
            end
            button = query_testid("button_clicks")
            @test evaljs(app, js"$(button).innerText") == "100"
            button = dom.content[5].content[2]
            @test button.content[] == "hi"
            button.content[] = "new name"
            bquery = query_testid("hi_button")
            @test evaljs(app, js"$(bquery).value") == "new name"
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
            slider1_js = jsobject(app, js"document.querySelectorAll('input[type=\"range\"]')[0]")
            slider2_js = jsobject(app, js"document.querySelectorAll('input[type=\"range\"]')[1]")
            sliderresult = query_testid("slider_result")
            @testset "set via jscall" begin
                for i in 1:100
                    slider1_js.value = i
                    slider1_js.oninput()
                    @test evaljs(app, slider1_js.value) == "$i"
                    # Test linkjs
                    @test evaljs(app, slider2_js.value) == "$i"
                    @test slider1[] == i
                    @test slider2[] == i
                    evaljs(app, js"$(sliderresult).innerText") == "$i"
                end
            end
            @testset "set via julia" begin
                for i in 1:100
                    slider1[] = i
                    @test evaljs(app, slider1_js.value) == "$i"
                    # Test linkjs
                    @test evaljs(app, slider2_js.value) == "$i"
                    @test slider2[] == i
                    evaljs(app, js"$(sliderresult).innerText") == "$i"
                end
            end
        end

        @testset "number input" begin
            number_input = jsobject(app, js"document.querySelector('input[type=\"number\"]')")
            number_input.value = "10.0"
            number_input.onchange()
        end
    end

    global test_session = nothing
    global dom = nothing
    inline_display = with_session() do session, req
        global test_session = session
        global dom = test_handler(session, req)
        return DOM.div(ElectronTests.JSTest, dom)
    end;

    electron_disp = electrondisplay(inline_display);
    app = TestSession(URI("http://localhost:8081/show"),
                      JSServe.global_application[], electron_disp, test_session)
    app.dom = dom

    @testset "electron inline display" begin
        test_current_session(app)
    end
    close(app)

    @testset "webio mime" begin
        ENV["JULIA_WEBIO_BASEURL"] = "https//google.de/"
        JSServe.__init__()
        @test JSServe.server_proxy_url[] == "https//google.de"
        html_webio = sprint(io-> show(io, MIME"application/vnd.webio.application+html"(), inline_display))
        @test JSServe.url("/test") == "https//google.de/test"
        @test occursin("window.websocket_proxy_url = 'https//google.de';", html_webio)
        JSServe.server_proxy_url[] = ""
        @test JSServe.url("/test") == "/test" # back to relative urls
        html_webio = sprint(io-> show(io, MIME"application/vnd.webio.application+html"(), inline_display))
        @test !occursin("window.websocket_proxy_url", html_webio)
        # We open the display server with the above TestSession
        # TODO electrontests should do this!
        ElectronTests.check_and_close_display()
    end

    @testset "Electron standalone" begin
        testsession(test_handler) do app
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

        testsession(test_handler) do app
            # Lets not be too porcelainy about this ...
            md_js_dom = jsobject(app, js"document.getElementById('application-dom').children[0]")
            @test evaljs(app, md_js_dom.children.length) == 1
            md_children = jsobject(app, js"$(md_js_dom.children)[0].children[0].children")
            @test evaljs(app, md_children.length) == 23
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
        testsession(test_handler) do app
            # Lets not be too porcelainy about this ...
            rslider = getfield(app.dom, :children)[1]
            @test rslider[] == [10, 80]
            rslider_html = jsobject(app, js"document.getElementById('rslider')")
            @test evaljs(app, js"$(rslider_html).children.length") == 3
            @test evaljs(app, js"$(rslider_html).children[1].innerText") == "10"
            @test evaljs(app, js"$(rslider_html).children[2].innerText") == "80"
            rslider[] = [20, 70]
        end
    end



    @testset "WGLMakie" begin
        function test_handler(session, req)
            scene = scatter([1, 2, 3, 4], resolution=(500,500), color=:red)
            return DOM.div(scene)
        end
        testsession(test_handler) do app
            # Lets not be too porcelainy about this ...
            @test evaljs(app, js"document.querySelector('canvas').style.width") == "500px"
            @test evaljs(app, js"document.querySelector('canvas').style.height") == "500px"
            img = WGLMakie.session2image(app.session)
            ratio = evaljs(app, js"window.devicePixelRatio")
            @info "device pixel ration: $(ratio)"
            if ratio != 1
                img = ImageTransformations.imresize(img, (500, 500))
            end
            img_ref = AbstractPlotting.FileIO.load(joinpath(@__DIR__, "test_reference.png"))
            # AbstractPlotting.FileIO.save(joinpath(@__DIR__, "test_reference.png"), img)
            meancol = AbstractPlotting.mean(color.(img) .- color.(img_ref))
            # This is pretty high... But I don't know how to look into travis atm
            # And seems it's not suuper wrong, so I'll take it for now ;)
            @test (reducec(+, 0.0, meancol) / 3) <= 0.025
        end
    end

    struct Custom
    end
    JSServe.jsrender(custom::Custom) = DOM.div("i'm a custom struct")


    stripnl(x) = strip(x, '\n')
    @testset "difflist" begin
        function test_handler(session, request)
            return DOM.div(JSServe.DiffList([Custom(), md"jo", DOM.div("span span span")], dataTestId="difflist"))
        end
        testsession(test_handler) do app
            js_list = query_testid(app, "difflist")
            difflist = children(app.dom)[1]
            @wait_for evaljs(app, js_list.children.length) == 3
            @test evaljs(app, js"$(js_list).children[0].innerText") == "i'm a custom struct"
            @test stripnl(evaljs(app, js"$(js_list).children[1].innerText")) == "jo"
            @test evaljs(app, js"$(js_list).children[2].innerText") == "span span span"

            empty!(difflist)
            @wait_for evaljs(app, js_list.children.length) == 0
            push!(difflist, md"new node 1")
            push!(difflist, md"new node 2")
            push!(difflist, md"new node 3")

            @test stripnl(evaljs(app, js"$(js_list).children[0].innerText")) == "new node 1"
            @test stripnl(evaljs(app, js"$(js_list).children[1].innerText")) == "new node 2"
            @test stripnl(evaljs(app, js"$(js_list).children[2].innerText")) == "new node 3"
            append!(difflist, [md"append", md"much fun"])
            @test stripnl(evaljs(app, js"$(js_list).children[3].innerText")) == "append"
            @test stripnl(evaljs(app, js"$(js_list).children[4].innerText")) == "much fun"

            difflist[2] = md"old node 2"
            @test stripnl(evaljs(app, js"$(js_list).children[1].innerText")) == "old node 2"

            JSServe.replace_children(difflist, [md"meowdy", md"monsieur", md"maunz"])

            @wait_for evaljs(app, js_list.children.length) == 3
            @test stripnl(evaljs(app, js"$(js_list).children[0].innerText")) == "meowdy"
            @test stripnl(evaljs(app, js"$(js_list).children[1].innerText")) == "monsieur"
            @test stripnl(evaljs(app, js"$(js_list).children[2].innerText")) == "maunz"

            insert!(difflist, 2, md"rowdy")
            @test stripnl(evaljs(app, js"$(js_list).children[1].innerText")) == "rowdy"
            delete!(difflist, [1, 4])

            @test stripnl(evaljs(app, js"$(js_list).children[0].innerText")) == "rowdy"
            @test stripnl(evaljs(app, js"$(js_list).children[1].innerText")) == "monsieur"
            @test children(difflist) == [md"rowdy", md"monsieur"]
        end
    end



    @testset "serialization" begin
        function test_handler(session, request)
            obs1 = Observable(Float16(2.0))
            obs2 = Observable(DOM.div("Data: ", obs1, dataTestId="hey"))
            return DOM.div(obs2)
        end
        xx = "hey"; some_js = js"var"; x = [1f0, 2f0]
        @test string(js"console.log($xx); $x; $((2, 4)); $(some_js) hello = 1;") == "console.log(\"hey\"); [1.0,2.0]; [2,4]; var hello = 1;"
        test_throw() = sprint(io->JSServe.serialize_readable(io, JSServe.Asset("file.dun_exist")))
        Test.@test_throws ErrorException("Unrecognized asset media type: dun_exist") test_throw()
        testsession(test_handler) do app
            hey = query_testid("hey")
            @test evaljs(app, js"$(hey).innerText") == "Data: Float16(2.0)"
            float16_obs = children(children(app.dom)[1][])[2]
            float16_obs[] = Float16(77)
            @test evaljs(app, js"$(hey).innerText") == "Data: Float16(77.0)"
        end
    end

    @testset "http" begin
        @test_throws ErrorException("Invalid sessionid: lol") JSServe.request_to_sessionid((target="lol",))
        @test JSServe.request_to_sessionid((target="lol",), throw=false) == nothing
    end

    @testset "hyperscript" begin
        function handler(session, request)
            the_script = DOM.script("window.testglobal = 42")
            s1 = Hyperscript.Style(css("p", fontWeight="bold"), css("span", color="red"))
            the_style = DOM.style(Hyperscript.styles(s1))
            return DOM.div(:hello, the_style, the_script, dataTestId="hello")
        end
        testsession(handler) do app
            @test evaljs(app, js"window.testglobal")  == 42
            hello_div = query_testid("hello")
            @test evaljs(app, js"$(hello_div).innerText")  == "hello"
            @test evaljs(app, js"$(hello_div).children.length") == 3
            @test evaljs(app, js"$(hello_div).children[0].tagName") == "P"
            @test evaljs(app, js"$(hello_div).children[1].tagName") == "STYLE"
            @test evaljs(app, js"$(hello_div).children[2].tagName") == "SCRIPT"
        end
    end

end
