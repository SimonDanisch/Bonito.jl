# Shared helper functions for tests.
# Included once from runtests.jl to avoid method redefinition warnings
# when test files are included multiple times (e.g. Default + DualWebsocket passes).

# From threading.jl
function electron_evaljs(window, js)
    js_str = sprint(show, js)
    return run(window, js_str)
end

function is_fully_loaded(window)
    return electron_evaljs(window, js"""(()=> {
        if (Bonito && Bonito.can_send_to_julia && Bonito.can_send_to_julia()){
            const elem = document.querySelectorAll('select')
            if (elem && elem.length == 2) {
                return true
            }
        }
        return false
    })()
    """)
end

function test_dom(window)
    while !is_fully_loaded(window)
        sleep(0.01)
    end
    electron_evaljs(window, js"document.querySelectorAll('select').length") == 2 || return false
    dropdown1 = js"document.querySelectorAll('select')[0]"
    dropdown2 = js"document.querySelectorAll('select')[1]"

    electron_evaljs(window, js"$(dropdown1).selectedIndex") == 0 || return false
    electron_evaljs(window, js"$(dropdown2).selectedIndex") == 1 || return false

    electron_evaljs(
        window,
        js"(()=> {
        const select = $(dropdown1)
        select.selectedIndex = 1;
        const event = new Event('change');
        select.dispatchEvent(event);
    })()")
    electron_evaljs(
        window,
        js"(()=> {
        const select = $(dropdown2)
        select.selectedIndex = 2;
        const event = new Event('change');
        select.dispatchEvent(event);
    })()")
    return true
end

# From components.jl
function styleable_slider_app(s, r)
    a = StylableSlider(1:4; value=1)
    b = StylableSlider(1:4; index=2)
    c = StylableSlider(["a", "b"]; value="b")
    return DOM.div(a, b, c)
end

# From widgets.jl
function checkbox_handler(session, request)
    global test_observable
    test_observable = Observable(Dict{String, Any}())
    checkbox1 = Bonito.Checkbox(true)
    checkbox2 = Bonito.Checkbox(false)

    on(checkbox1) do value
        test_observable[] = Dict{String, Any}("checkbox1" => value)
    end
    on(checkbox2) do value
        test_observable[] = Dict{String, Any}("checkbox2" => value)
    end

    return DOM.div(checkbox1, checkbox2)
end

function dropdown_handler(session, request)
    global test_observable
    test_observable = Observable(Dict{String, Any}())
    global dropdown1 = Bonito.Dropdown(["a", "b", "c"])
    dropdown2 = Bonito.Dropdown(["a2", "b2", "c2"]; index=2)

    on(dropdown1.value) do value
        test_observable[] = Dict{String,Any}("dropdown1" => value)
    end
    on(dropdown2.value) do value
        test_observable[] = Dict{String,Any}("dropdown2" => value)
    end

    return DOM.div(dropdown1, dropdown2)
end

function table_handler(session, request)
    test_table_data = [
        (attribute="price", apartment_A=1200.0, apartment_B=950.0, apartment_C=1350.0),
        (attribute="area", apartment_A=75.5, apartment_B=65.2, apartment_C=85.0),
        (attribute="floor", apartment_A=3, apartment_B=2, apartment_C=4)
    ]

    basic_table = Bonito.Table(test_table_data)

    function test_class_callback(table, row, col, val)
        if col == 1
            return "cell-default"
        elseif isa(val, Number) && val > 1000
            return "cell-good"
        elseif isa(val, Number) && val < 70
            return "cell-bad"
        else
            return "cell-neutral"
        end
    end

    function test_style_callback(table, row, col, val)
        if col == 1
            return "font-weight: bold;"
        elseif isa(val, Number) && val > 1000
            return "background-color: lightgreen;"
        else
            return ""
        end
    end

    custom_table = Bonito.Table(test_table_data;
                               class_callback=test_class_callback,
                               style_callback=test_style_callback)

    no_sort_table = Bonito.Table(test_table_data;
                                allow_row_sorting=false,
                                allow_column_sorting=false)

    styled_table = Bonito.Table(test_table_data;
                               class="my-custom-table")

    return DOM.div(
        DOM.div(basic_table; id="basic_table"),
        DOM.div(custom_table; id="custom_table"),
        DOM.div(no_sort_table; id="no_sort_table"),
        DOM.div(styled_table; id="styled_table")
    )
end

function empty_table_handler(session, request)
    empty_data = NamedTuple{(:col1, :col2), Tuple{String, Int}}[]
    empty_table = Bonito.Table(empty_data)
    return DOM.div(empty_table; id="empty_table")
end

function missing_values_table_handler(session, request)
    data_with_missing = [
        (name="Alice", age=25, salary=50000.0),
        (name="Bob", age=missing, salary=60000.0),
        (name="Charlie", age=30, salary=missing)
    ]
    table_with_missing = Bonito.Table(data_with_missing)
    return DOM.div(table_with_missing; id="missing_table")
end

# From markdown.jl
function markdown_test_handler(session, req)
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
        @test evaljs(app, js"document.querySelectorAll('button').length") == 1
        bquery = query_testid("hi_button")
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
        val = test_value(app, ()-> (button.value[] = true))
        @test val["button"] == true
    end

    @testset "textfield" begin
        @test evaljs(app, js"document.querySelectorAll('input[type=\"textfield\"]').length") == 1
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
        slider1 = dom.content[2].content[2]
        slider2 = dom.content[3].content[2]
        slider1_js = js"document.querySelectorAll('input[type=\"range\"]')[0]"
        slider2_js = query_testid("linked_value")
        sliderresult = query_testid("slider_result")

        @testset "set via julia" begin
            for i in 1:2:100
                slider1[] = i
                @test evaljs(app, js"$(slider1_js).value") == "$i"
                @test evaljs(app, js"$(slider2_js).innerText") == "$i"
                @test slider2[] == i
                evaljs(app, js"$(sliderresult).innerText") == "$i"
            end
        end
    end
end
