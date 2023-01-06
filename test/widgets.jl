function handler(session, request)
    global test_observable
    test_observable = Observable(Dict{String, Any}())
    checkbox1 = JSServe.Checkbox(true)
    checkbox2 = JSServe.Checkbox(false)

    on(checkbox1) do value
        test_observable[] = Dict{String, Any}("checkbox1" => value)
    end
    on(checkbox2) do value
        test_observable[] = Dict{String, Any}("checkbox2" => value)
    end

    return DOM.div(checkbox1, checkbox2)
end

testsession(handler, port=8558) do app
    checkbox1_jl = children(app.dom)[1]
    checkbox2_jl = children(app.dom)[2]
    @test evaljs(app, js"document.querySelectorAll('input[type=\"checkbox\"]').length") == 2
    checkbox1 = js"document.querySelectorAll('input[type=\"checkbox\"]')[0]"
    checkbox2 = js"document.querySelectorAll('input[type=\"checkbox\"]')[1]"
    @test evaljs(app, js"$(checkbox1).checked") == true
    @test evaljs(app, js"$(checkbox2).checked") == false
    val = test_value(app, js"$(checkbox1).click()")
    @test val["checkbox1"] == false
    @test checkbox1_jl[] == false
    val = test_value(app, js"$(checkbox2).click()")
    @test val["checkbox2"] == true
    @test checkbox2_jl[] == true
    # button press from Julia
    checkbox1_jl[] = true # this won't trigger onchange!!!!
    @test evaljs(app, js"$(checkbox1).checked") == true
    checkbox2_jl[] = false
    @test evaljs(app, js"$(checkbox2).checked") == false
end


function dropdown_handler(session, request)
    global test_observable
    test_observable = Observable(Dict{String, Any}())
    global dropdown1 = JSServe.Dropdown(["a", "b", "c"])
    dropdown2 = JSServe.Dropdown(["a2", "b2", "c2"]; index=2)

    on(dropdown1.option) do value
        test_observable[] = Dict{String,Any}("dropdown1" => value)
    end
    on(dropdown2.option) do value
        test_observable[] = Dict{String,Any}("dropdown2" => value)
    end

    return DOM.div(dropdown1, dropdown2)
end

testsession(dropdown_handler, port=8558) do app
    checkbox1_jl = children(app.dom)[1]
    checkbox2_jl = children(app.dom)[2]
    @test evaljs(app, js"document.querySelectorAll('select').length") == 2
    dropdown1 = js"document.querySelectorAll('select')[0]"
    dropdown2 = js"document.querySelectorAll('select')[1]"

    @test evaljs(app, js"$(dropdown1).selectedIndex") == 0 # 0 indexed if directly accessed
    @test evaljs(app, js"$(dropdown2).selectedIndex") == 1

    evaljs(app, js"(()=> {
        const select = $(dropdown1)
        select.selectedIndex = 1;
        const event = new Event('change');
        select.dispatchEvent(event);
    })()")
    evaljs(app, js"(()=> {
        const select = $(dropdown2)
        select.selectedIndex = 2;
        const event = new Event('change');
        select.dispatchEvent(event);
    })()")
    @test checkbox1_jl.option[] == "b"
    @test checkbox2_jl.option[] == "c2"
end
