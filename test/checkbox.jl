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
