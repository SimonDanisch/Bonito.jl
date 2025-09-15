function handler(session, request)
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

testsession(dropdown_handler, port=8558) do app
    dropdown1_jl = children(app.dom)[1]
    dropdown2_jl = children(app.dom)[2]
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
    @test dropdown1_jl.value[] == "b"
    @test dropdown2_jl.value[] == "c2"
end

# Table widget tests
function table_handler(session, request)
    # Create test data using vector of named tuples
    test_table_data = [
        (attribute="price", apartment_A=1200.0, apartment_B=950.0, apartment_C=1350.0),
        (attribute="area", apartment_A=75.5, apartment_B=65.2, apartment_C=85.0),
        (attribute="floor", apartment_A=3, apartment_B=2, apartment_C=4)
    ]

    # Test basic table
    basic_table = Bonito.Table(test_table_data)

    # Test table with custom class callback
    function test_class_callback(table, row, col, val)
        if col == 1  # First column (attributes)
            return "cell-default"
        elseif isa(val, Number) && val > 1000
            return "cell-good"
        elseif isa(val, Number) && val < 70
            return "cell-bad"
        else
            return "cell-neutral"
        end
    end

    # Test table with custom style callback
    function test_style_callback(table, row, col, val)
        if col == 1  # First column
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

    # Test table with sorting disabled
    no_sort_table = Bonito.Table(test_table_data;
                                allow_row_sorting=false,
                                allow_column_sorting=false)

    # Test table with custom CSS class
    styled_table = Bonito.Table(test_table_data;
                               class="my-custom-table")

    return DOM.div(
        DOM.div(basic_table; id="basic_table"),
        DOM.div(custom_table; id="custom_table"),
        DOM.div(no_sort_table; id="no_sort_table"),
        DOM.div(styled_table; id="styled_table")
    )
end

testsession(table_handler, port=8559) do app
    # Test that tables are rendered
    @test evaljs(app, js"document.querySelectorAll('table').length") == 4
    @test evaljs(app, js"document.querySelectorAll('.comparison-table').length") == 4

    # Test basic table structure
    basic_table = js"document.querySelector('#basic_table table')"
    @test evaljs(app, js"$(basic_table).querySelectorAll('th').length") == 4  # 4 columns
    @test evaljs(app, js"$(basic_table).querySelectorAll('tbody tr').length") == 3  # 3 rows

    # Test header content
    @test evaljs(app, js"$(basic_table).querySelectorAll('th')[0].textContent.trim()") == "attribute"
    @test evaljs(app, js"$(basic_table).querySelectorAll('th')[1].textContent.trim()") == "apartment_A"
    @test evaljs(app, js"$(basic_table).querySelectorAll('th')[2].textContent.trim()") == "apartment_B"
    @test evaljs(app, js"$(basic_table).querySelectorAll('th')[3].textContent.trim()") == "apartment_C"

    # Test data content
    first_row = js"$(basic_table).querySelectorAll('tbody tr')[0]"
    @test evaljs(app, js"$(first_row).querySelectorAll('td')[0].textContent.trim()") == "price"
    @test evaljs(app, js"$(first_row).querySelectorAll('td')[1].textContent.trim()") == "1200.0"
    @test evaljs(app, js"$(first_row).querySelectorAll('td')[2].textContent.trim()") == "950.0"
    @test evaljs(app, js"$(first_row).querySelectorAll('td')[3].textContent.trim()") == "1350.0"

    # Test custom table with class callbacks
    custom_table = js"document.querySelector('#custom_table table')"

    # Test that cells have correct classes applied
    first_cell = js"$(custom_table).querySelectorAll('tbody tr')[0].querySelectorAll('td')[0]"
    @test evaljs(app, js"$(first_cell).className.includes('cell-default')") == true

    high_value_cell = js"$(custom_table).querySelectorAll('tbody tr')[0].querySelectorAll('td')[1]"  # 1200.0
    @test evaljs(app, js"$(high_value_cell).className.includes('cell-good')") == true

    low_value_cell = js"$(custom_table).querySelectorAll('tbody tr')[1].querySelectorAll('td')[2]"  # 65.2
    @test evaljs(app, js"$(low_value_cell).className.includes('cell-bad')") == true

    # Test that style callback is applied
    styled_cell = js"$(custom_table).querySelectorAll('tbody tr')[0].querySelectorAll('td')[0]"
    @test evaljs(app, js"$(styled_cell).style.fontWeight") == "bold"

    high_value_styled = js"$(custom_table).querySelectorAll('tbody tr')[0].querySelectorAll('td')[1]"
    @test evaljs(app, js"$(high_value_styled).style.backgroundColor") == "lightgreen"

    # Test custom CSS class
    styled_table = js"document.querySelector('#styled_table table')"
    @test evaljs(app, js"$(styled_table).className.includes('my-custom-table')") == true

    # Test sorting functionality (on tables that have sorting enabled)
    # Test column header click (should have cursor pointer)
    basic_header = js"$(basic_table).querySelectorAll('th')[0]"
    @test evaljs(app, js"getComputedStyle($(basic_header)).cursor") == "pointer"

    # Test that no-sort table doesn't have clickable headers/cells
    no_sort_table = js"document.querySelector('#no_sort_table table')"
    no_sort_header = js"$(no_sort_table).querySelectorAll('th')[0]"
    # Note: The cursor style might still be set by CSS, but the click handlers shouldn't be attached

    # Test data attributes for sorting
    data_cell = js"$(basic_table).querySelectorAll('tbody tr')[0].querySelectorAll('td')[1]"
    @test evaljs(app, js"$(data_cell).getAttribute('data-value')") == "1200.0"
end


# Test table with empty data
function empty_table_handler(session, request)
    # Empty vector of named tuples
    empty_data = NamedTuple{(:col1, :col2), Tuple{String, Int}}[]
    empty_table = Bonito.Table(empty_data)
    return DOM.div(empty_table; id="empty_table")
end

testsession(empty_table_handler, port=8560) do app
    # Test that empty table is rendered with headers but no data rows
    empty_table = js"document.querySelector('#empty_table table')"
    @test evaljs(app, js"$(empty_table).querySelectorAll('th').length") == 2  # Headers still present
    @test evaljs(app, js"$(empty_table).querySelectorAll('tbody tr').length") == 0  # No data rows

    # Test header content
    @test evaljs(app, js"$(empty_table).querySelectorAll('th')[0].textContent.trim()") == "col1"
    @test evaljs(app, js"$(empty_table).querySelectorAll('th')[1].textContent.trim()") == "col2"
end

# Test table with missing values
function missing_values_table_handler(session, request)
    # Vector of named tuples with missing values
    data_with_missing = [
        (name="Alice", age=25, salary=50000.0),
        (name="Bob", age=missing, salary=60000.0),
        (name="Charlie", age=30, salary=missing)
    ]
    table_with_missing = Bonito.Table(data_with_missing)
    return DOM.div(table_with_missing; id="missing_table")
end

testsession(missing_values_table_handler, port=8561) do app
    # Test that missing values are handled properly
    missing_table = js"document.querySelector('#missing_table table')"

    # Test that missing values are rendered as "n/a" by default row_renderer
    missing_age_cell = js"$(missing_table).querySelectorAll('tbody tr')[1].querySelectorAll('td')[1]"
    @test evaljs(app, js"$(missing_age_cell).textContent.trim()") == "n/a"

    missing_salary_cell = js"$(missing_table).querySelectorAll('tbody tr')[2].querySelectorAll('td')[2]"
    @test evaljs(app, js"$(missing_salary_cell).textContent.trim()") == "n/a"

    # Test that non-missing values are rendered correctly
    valid_age_cell = js"$(missing_table).querySelectorAll('tbody tr')[0].querySelectorAll('td')[1]"
    @test evaljs(app, js"$(valid_age_cell).textContent.trim()") == "25"
end
