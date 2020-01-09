using Hyperscript, Markdown, Test
using JSServe, Observables
using JSServe: Session, evaljs, linkjs, update_dom!, div, active_sessions
using JSServe: @js_str, onjs, Button, TextField, Slider, JSString, Dependency, with_session, jsobject
using JSServe.DOM
using JSServe.HTTP
using Electron, URIParser
using Random
using ElectronDisplay

global dom
global test_session
global test_observable

"""
    monkey_close(app)
`close(application)` Is a bit buggy atm, and relies on an upstream fix & needs
some more debugging on linux... While this isn't fixed/merged, we monkey patch it!
"""
function monkey_close(application)
    try
        # close the global application created by display!
        close(application)
        # First get after close will still go through, see: https://github.com/JuliaWeb/HTTP.jl/pull/494
    catch e
        # TODO why does this error on travis? Possibly linux in general
        dump(e)
    end

    HTTP.get("http://127.0.0.1:8081/", readtimeout=3, retries=1)
    return
end

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
    @test_value(statement)
Executes statemen (js code, or julia function with 0 args),
And waits on `test_observable` to push a new value!
Returns new value from `test_observable`
"""
macro test_value(statement)
    return quote
        # First start waiting on the test communication channel
        # We do this async before scheduling the js, since otherwise there is a
        # chance, that the event gets triggered before we have a chance to wait for it
        # which would make use wait forever
        val_t = @async wait_on_test_observable()
        # eval our js expression that is supposed to write something to test_observable
        statement = $(esc(statement))
        if statement isa JSServe.JSCode
            JSServe.evaljs(test_session, statement)
        else
            statement()
        end
        fetch(val_t) # fetch the value!
    end
end
# inline session for a little bit less writing!
function runjs(js)
    JSServe.evaljs_value(test_session, js)
end

function test_handler(session, req)
    global dom, test_session, test_observable
    test_session = session

    s1 = Slider(1:100)
    s2 = Slider(1:100)
    b = Button("hi")
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

    dom = md"""
    # IS THIS REAL?

    My first slider: $(s1)

    My second slider: $(s2)

    Test: $(s1.value)

    The BUTTON: $(b)

    Type something for the list: $(t)

    some list $(t.value)
    """
    return dom
end

# load(win, local_url)

function test_current_session()
    wait(test_session.js_fully_loaded)
    # toggle_devtools(win)

    @test runjs(js"document.getElementById('application-dom').children.length") == 1
    @test runjs(js"document.getElementById('application-dom').children[0].children[0].innerText") == "IS THIS REAL?"
    @test runjs(js"document.querySelectorAll('input[type=\"button\"]').length") == 1
    @test runjs(js"document.querySelectorAll('input[type=\"range\"]').length") == 2

    @testset "button" begin
        # It's in the dom!
        @test runjs(js"document.querySelectorAll('input[type=\"button\"]').length") == 1
        # Spam the button press on the JS side a bit, to make sure we're not loosing events!
        for i in 1:100
            val = @test_value(js"document.querySelectorAll('input[type=\"button\"]')[0].click()")
            @test val["button"] == true
        end
        button = dom.content[5].content[2]
        @test button.content[] == "hi"
        button.content[] = "new name"
        @test runjs(js"document.querySelector('input[type=\"button\"]').value") == "new name"
        # button press from Julia
        val = @test_value(()-> button.value[] = true)
        @test val["button"] == true
    end

    @testset "textfield" begin
        @test runjs(js"document.querySelectorAll('input[type=\"textfield\"]').length") == 1
        # @test runjs(js"document.querySelector('input[type=\"textfield\"]').value") == "Write!"
        # Spam the button press a bit!
        text_obs = dom.content[end].content[2]
        textfield = dom.content[end-1].content[2]
        @testset "setting value from js" begin
            for i in 1:10
                str = randstring(10)
                do_input = js"""
                    var tfield = document.querySelector('input[type=\"textfield\"]');
                    tfield.value = $(str);
                    tfield.onchange();
                """
                val = @test_value(do_input)
                @test val["textfield"] == str
                @test text_obs[] == str
                runjs(js"document.querySelector('#application-dom > span > div:nth-child(18) > span').innerText") == str
                @test textfield[] == str
            end
        end
        @testset "setting value from julia" begin
            for i in 1:10
                str = randstring(10)
                val = @test_value(()-> textfield[] = str)
                @test val["textfield"] == str
                @test text_obs[] == str
                runjs(js"document.querySelector('#application-dom > span > div:nth-child(18) > span').innerText") == str
                @test textfield[] == str
            end
        end
    end

    @testset "slider" begin
        # We test with JSCall this time, to test it as well ;)
        slider1 = dom.content[2].content[2]
        slider2 = dom.content[3].content[2]
        slider1_js = jsobject(test_session, js"document.querySelectorAll('input[type=\"range\"]')[0]")
        slider2_js = jsobject(test_session, js"document.querySelectorAll('input[type=\"range\"]')[1]")
        @testset "set via jscall" begin
            for i in 1:100
                slider1_js.value = i
                slider1_js.oninput()
                @test runjs(slider1_js.value) == "$i"
                # Test linkjs
                @test runjs(slider2_js.value) == "$i"
                @test slider1[] == i
                @test slider2[] == i
                runjs(js"document.querySelector('#application-dom > span > div:nth-child(9) > span').innerText") == "$i"
            end
        end
        @testset "set via julia" begin
            for i in 1:100
                slider1[] = i
                @test runjs(slider1_js.value) == "$i"
                # Test linkjs
                @test runjs(slider2_js.value) == "$i"
                @test slider2[] == i
                runjs(js"document.querySelector('#application-dom > span > div:nth-child(9) > span').innerText") == "$i"
            end
        end
    end
end


x = with_session() do session, req
    test_handler(session, req)
end

electon_disp = electrondisplay(x)

@testset "electron inline display" begin
    test_current_session()
end

close(electon_disp)

@testset "starting and closing of app" begin
    monkey_close(JSServe.global_application[])
    http_app = JSServe.Application(test_handler, "127.0.0.1", 8081, verbose=true)
    # JSServe.start(app, verbose=true)
    response = HTTP.get("http://127.0.0.1:8081/")
    @test response.status == 200

    monkey_close(http_app)

    connection_refused = try
        x = HTTP.get("http://127.0.0.1:8081/", readtimeout=3, retries=1)
        false
    catch e
        e isa HTTP.IOExtras.IOError && e.e == Base.IOError("connect: connection refused (ECONNREFUSED)", -4078)
    end

    JSServe.start(http_app)
    response = HTTP.get("http://127.0.0.1:8081/")
    @test response.status == 200
end

@testset "Electron standalone" begin
    app = Electron.Application()
    local_url = URI("http://localhost:8081")
    win = Window(app, URI("http://localhost:8081"))
    test_current_session()
    close(win)
end


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
    return dom
end

@testset "markdown" begin
    # Lets not be too porcelainy about this ...
    md_js_dom = jsobject(test_session, js"document.getElementById('application-dom')")
    @test runjs(md_js_dom.children.length) == 1
    md_children = jsobject(test_session, js"$(md_js_dom.children)[0].children")
    @test runjs(md_children.length) == 23
    @test occursin("This is the first footnote.", runjs(js"$(md_children)[22].innerText"))
    @test runjs(js"$(md_children)[2].children[0].children[0].tagName") == "IMG"
end
