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
