# checkbox_handler, dropdown_handler, table_handler, empty_table_handler,
# missing_values_table_handler defined in test_helpers.jl

testsession(checkbox_handler, port=8558) do app
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
    basic_header = js"$(basic_table).querySelectorAll('th')[0]"
    @test evaljs(app, js"getComputedStyle($(basic_header)).cursor") == "pointer"

    # Test data attributes for sorting
    data_cell = js"$(basic_table).querySelectorAll('tbody tr')[0].querySelectorAll('td')[1]"
    @test evaljs(app, js"$(data_cell).getAttribute('data-value')") == "1200.0"
end


# Test table with empty data
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
