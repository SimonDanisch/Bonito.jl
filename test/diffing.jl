struct Custom
end
JSServe.jsrender(custom::Custom) = DOM.div("i'm a custom struct")


stripnl(x) = strip(x, '\n')
@testset "difflist" begin

    function test_handler(session, request)
        return DOM.div(JSServe.DiffList([Custom(), md"jo", DOM.div("span span span")], dataTestId="difflist"))
    end

    testsession(test_handler, port=8555) do app
        js_list = query_testid(app, "difflist")
        difflist = children(app.dom)[1]

        connected_list = Observable(Any[])
        JSServe.connect!(connected_list, difflist)
        test_connection() = connected_list[] == difflist.children

        @wait_for evaljs(app, js_list.children.length) == 3
        @test evaljs(app, js"$(js_list).children[0].innerText") == "i'm a custom struct"
        @test stripnl(evaljs(app, js"$(js_list).children[1].innerText")) == "jo"
        @test evaljs(app, js"$(js_list).children[2].innerText") == "span span span"

        empty!(difflist)
        @wait_for evaljs(app, js_list.children.length) == 0
        push!(difflist, md"new node 1")
        push!(difflist, md"new node 2")
        push!(difflist, md"new node 3")

        @test test_connection()

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

        @test test_connection()

        @test stripnl(evaljs(app, js"$(js_list).children[0].innerText")) == "meowdy"
        @test stripnl(evaljs(app, js"$(js_list).children[1].innerText")) == "monsieur"
        @test stripnl(evaljs(app, js"$(js_list).children[2].innerText")) == "maunz"

        insert!(difflist, 2, md"rowdy")
        @test stripnl(evaljs(app, js"$(js_list).children[1].innerText")) == "rowdy"
        delete!(difflist, [1, 4])

        @test test_connection()

        @test stripnl(evaljs(app, js"$(js_list).children[0].innerText")) == "rowdy"
        @test stripnl(evaljs(app, js"$(js_list).children[1].innerText")) == "monsieur"
        @test children(difflist) == [md"rowdy", md"monsieur"]

        @test test_connection()
        JSServe.replace_children(difflist, [md"$i" for i in 1:3000])
        insert!(difflist, 2999, md"hehe")
        @test length(difflist) == 3001
        @test difflist[2999] == md"hehe"
        @test difflist[3000].content[1] == 2999
        @test difflist[3001].content[1] == 3000
        @test stripnl(evaljs(app, js"$(js_list).children[2999-1].innerText")) == "hehe"
        @test stripnl(evaljs(app, js"$(js_list).children[3000-1].innerText")) == "2999"
        @test stripnl(evaljs(app, js"$(js_list).children[3001-1].innerText")) == "3000"
    end
end
