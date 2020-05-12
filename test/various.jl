
@testset "serialization" begin
    function test_handler(session, request)
        obs1 = Observable(Float16(2.0))
        obs2 = Observable(DOM.div("Data: ", obs1, dataTestId="hey"))
        return DOM.div(obs2)
    end
    xx = "hey"; some_js = js"var"; x = [1f0, 2f0]
    @test string(js"console.log($xx); $x; $((2, 4)); $(some_js) hello = 1;") == "console.log(\"hey\"); [1.0,2.0]; [2,4]; var hello = 1;"
    asset = JSServe.Asset("file.dun_exist"; check_isfile=false)
    test_throw() = sprint(io->JSServe.serialize_readable(io, JSServe.Asset("file.dun_exist")))
    Test.@test_throws ErrorException("Unrecognized asset media type: dun_exist") test_throw()
    testsession(test_handler, port=8555) do app
        hey = query_testid("hey")
        @test evaljs(app, js"$(hey).innerText") == "Data: 2.0"
        float16_obs = children(children(app.dom)[1][])[2]
        float16_obs[] = Float16(77)
        @test evaljs(app, js"$(hey).innerText") == "Data: 77"
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
    testsession(handler, port=8555) do app
        @test evaljs(app, js"window.testglobal") == 42
        hello_div = query_testid("hello")
        @test evaljs(app, js"$(hello_div).innerText")  == "hello"
        @test evaljs(app, js"$(hello_div).children.length") == 3
        @test evaljs(app, js"$(hello_div).children[0].tagName") == "P"
        @test evaljs(app, js"$(hello_div).children[1].tagName") == "STYLE"
        @test evaljs(app, js"$(hello_div).children[2].tagName") == "SCRIPT"
    end
end
