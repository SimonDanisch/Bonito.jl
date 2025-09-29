# Render the widgets from WidgetsBase.jl

const BUTTON_STYLE = Styles(
    CSS(
        "font-weight" => 600,
        "border-width" => "1px",
        "border-color" => "#9CA3AF",
        "border-radius" => "0.25rem",
        "padding-left" => "0.75rem",
        "padding-right" => "0.75rem",
        "padding-top" => "0.25rem",
        "padding-bottom" => "0.25rem",
        "margin" => "0.25rem",
        "cursor" => "pointer",
        "min-width" => "8rem",
        "font-size" => "1rem",
        "background-color" => "white",
        "box-shadow" => "rgba(0, 0, 0, 0) 0px 0px 0px 0px, rgba(0, 0, 0, 0) 0px 0px 0px 0px, rgba(0, 0, 0, 0.1) 0px 1px 3px 0px, rgba(0, 0, 0, 0.1) 0px 1px 2px -1px";
    ),
    CSS(
        ":hover",
        "background-color" => "#F9FAFB",
        "box-shadow" => "rgba(0, 0, 0, 0) 0px 0px 0px 0px, rgba(0, 0, 0, 0) 0px 0px 0px 0px, rgba(0, 0, 0, 0.1) 0px 1px 3px 0px, rgba(0, 0, 0, 0.1) 0px 1px 2px -1px",
    ),
    CSS(
        ":focus",
        "outline" => "1px solid transparent",
        "outline-offset" => "1px",
        "box-shadow" => "rgba(66, 153, 225, 0.5) 0px 0px 0px 1px",
    ),
)

const BUTTON_EXAMPLE = """
App() do
    style = Styles(
        CSS("font-weight" => "500"),
        CSS(":hover", "background-color" => "silver"),
        CSS(":focus", "box-shadow" => "rgba(0, 0, 0, 0.5) 0px 0px 5px"),
    )
    button = Button("Click me"; style=style)
    on(button.value) do click::Bool
        @info "Button clicked!"
    end
    return button
end
"""

"""
    Button(name; style=Styles(), dom_attributes...)

A simple button, which can be styled a `style::Styles`. Set kwarg `style=nothing` to turn
off the default Bonito styling.

### Example

```julia
$(BUTTON_EXAMPLE)
```
"""
Button

function jsrender(session::Session, button::Button)
    style = get(button.attributes, :style, Styles())
    css = isnothing(style) ? Styles() : Styles(style, BUTTON_STYLE)
    button_dom = DOM.button(
        button.content[];
        onclick=js"event=> $(button.value).notify(true);",
        button.attributes...,
        style=css
    )
    onjs(session, button.content, js"x=> $(button_dom).innerText = x")
    return jsrender(session, button_dom)
end


const TEXTFIELD_EXAMPLE = """
App() do
    style = Styles(
        CSS("font-weight" => "500"),
        CSS(":hover", "background-color" => "silver"),
        CSS(":focus", "box-shadow" => "rgba(0, 0, 0, 0.5) 0px 0px 5px"),
    )
    textfield = TextField("write something"; style=style)
    on(textfield.value) do text::String
        @info text
    end
    return textfield
end
"""

"""
    TextField(default_text; style=Styles(), dom_attributes...)

A simple TextField, which can be styled via the `style::Styles` attribute, `style=nothing`
turns off the default Bonito styling.

### Example

```julia
$(TEXTFIELD_EXAMPLE)
```
"""
TextField

function jsrender(session::Session, tf::TextField)
    style = get(tf.attributes, :style, Styles())
    css = isnothing(style) ? Styles() : Styles(style, BUTTON_STYLE)
    return jsrender(
        session,
        DOM.input(;
            type="textfield",
            value=tf.value,
            onchange=js"event => $(tf.value).notify(event.srcElement.value);",
            tf.attributes...,
            style=css
        ),
    )
end

const NUMBERINPUT_EXAMPLE = """
App() do
    style = Styles(
        CSS("font-weight" => "500"),
        CSS(":hover", "background-color" => "silver"),
        CSS(":focus", "box-shadow" => "rgba(0, 0, 0, 0.5) 0px 0px 5px"),
    )
    numberinput = NumberInput(0.0; style=style)
    on(numberinput.value) do value::Float64
        @info value
    end
    return numberinput
end
"""

"""
    NumberInput(default_value; style=Styles(), dom_attributes...)

A simple NumberInput, which can be styled via the `style::Styles` attribute, `style=nothing`
turns off the default Bonito styling.

### Example

```julia
$(NUMBERINPUT_EXAMPLE)
```
"""
NumberInput

function jsrender(session::Session, ni::NumberInput)
    style = get(ni.attributes, :style, Styles())
    css = isnothing(style) ? Styles() : Styles(style, BUTTON_STYLE)
    return jsrender(
        session,
        DOM.input(;
            type="number",
            value=ni.value,
            onchange=js"event => {
                const new_value = parseFloat(event.srcElement.value);
                if ($(ni.value).value != new_value) {
                    $(ni.value).notify(new_value);
                }
            }",
            ni.attributes...,
            style=css,
        ),
    )
end

const DROPDOWN_EXAMPLE = """
App() do
    style = Styles(
        CSS("font-weight" => "500"),
        CSS(":hover", "background-color" => "silver"),
        CSS(":focus", "box-shadow" => "rgba(0, 0, 0, 0.5) 0px 0px 5px"),
    )
    dropdown = Dropdown(["a", "b", "c"]; index=2, style=style)
    on(dropdown.value) do value
        @info value
    end
    return dropdown
end
"""

"""
    Dropdown(options; index=1, option_to_string=string, style=Styles(), dom_attributes...)

A simple Dropdown, which can be styled via the `style::Styles` attribute, `style=nothing`
turns off the default Bonito styling.

### Example

```julia
$(DROPDOWN_EXAMPLE)
```
"""
struct Dropdown
    options::Observable{Vector{Any}}
    value::Observable{Any}
    option_to_string::Function
    option_index::Observable{Int}
    attributes::Dict{Symbol,Any}
    style::Styles
end

function Dropdown(options; index=1, option_to_string=string, style=Styles(), attributes...)
    option_index = convert(Observable{Int}, index)
    options = convert(Observable{Vector{Any}}, options)
    option = Observable{Any}(options[][option_index[]])
    onany(option_index, options) do index, options
        option[] = options[index]
        return nothing
    end
    css = isnothing(style) ? Styles() : Styles(style, BUTTON_STYLE)
    return Dropdown(
        options, option, option_to_string, option_index, Dict{Symbol,Any}(attributes), css
    )
end

function jsrender(session::Session, dropdown::Dropdown)
    string_options = map(x-> map(dropdown.option_to_string, x), session, dropdown.options)
    onchange = js"""
    function onload(element) {
        function onchange(e) {
            if (element === e.srcElement) {
                ($(dropdown.option_index)).notify(element.selectedIndex + 1);
            }
        }
        element.addEventListener("change", onchange);
        element.selectedIndex = $(dropdown.option_index[] - 1)
        function set_option_index(index) {
            if (element.selectedIndex === index - 1) {
                return
            }
            element.selectedIndex = index - 1;
        }
        $(dropdown.option_index).on(set_option_index);
        function set_options(opts) {
            element.selectedIndex = 0;
            // https://stackoverflow.com/questions/3364493/how-do-i-clear-all-options-in-a-dropdown-box
            element.options.length = 0;
            opts.forEach((opt, i) => element.options.add(new Option(opts[i], i)));
        }
        $(string_options).on(set_options);
    }
    """
    option2div(x) = DOM.option(x)
    dom = map(options -> map(option2div, options), session, string_options)[]

    select = DOM.select(dom; style=dropdown.style, dropdown.attributes...)
    Bonito.onload(session, select, onchange)
    return jsrender(session, select)
end


abstract type AbstractSlider{T} <: WidgetsBase.AbstractWidget{T} end

struct Slider{T} <: AbstractSlider{T}
    values::Observable{Vector{T}}
    value::Observable{T}
    index::Observable{Int}
    attributes::Dict{Symbol,Any}
end

function Slider(values::AbstractArray{T}; value=first(values), kw...) where {T}
    values_obs = convert(Observable{Vector{T}}, values)
    initial_idx = findfirst((==)(value), values_obs[])
    index = Observable(initial_idx)
    value_obs = Observable(values_obs[][initial_idx])
    return Slider(values_obs, value_obs, index, Dict{Symbol,Any}(kw))
end

function jsrender(session::Session, slider::Slider)
    # Hacky, but don't want to Pr WidgetsBase yet
    values = slider.values
    index = slider.index
    onjs(
        session,
        index,
        js"""(index) => {
            const values = $(values).value
            $(slider.value).notify(values[index - 1])
        }
        """,
    )

    return jsrender(
        session,
        DOM.input(;
            type="range",
            min=1,
            max=map(length, values),
            value=index,
            step=1,
            oninput=js"""(event)=> {
                const idx = event.srcElement.valueAsNumber;
                if (idx !== $(index).value) {
                    $(index).notify(idx)
                }
            }""",
            style=styles,
            slider.attributes...,
        ),
    )
end

function Base.setindex!(slider::AbstractSlider, value)
    # should be only numbers right now, which should also be sorted
    # This may change once we allow `Slider(array)` in WidgetsBase
    values = slider.values
    idx = findfirst(x -> x >= value, values[])

    if isnothing(idx)
        @warn(
            "Value $(value) out of range for the values of slider (highest value: $(last(values[]))). Setting to highest value!"
        )
        idx = length(values[])
    end
    slider.index[] = idx
    return idx
end


const CHECKBOX_EXAMPLE = """
App() do
    style = Styles(
        CSS(":hover", "background-color" => "silver"),
        CSS(":focus", "box-shadow" => "rgba(0, 0, 0, 0.5) 0px 0px 5px"),
    )
    checkbox = Checkbox(true; style=style)
    on(checkbox.value) do value::Bool
        @info value
    end
    return checkbox
end
"""

"""
    Checkbox(default_value; style=Styles(), dom_attributes...)

A simple Checkbox, which can be styled via the `style::Styles` attribute.
"""
Checkbox

function jsrender(session::Session, tb::Checkbox)
    style = Styles(Styles("min-width" => "auto", "transform" => "scale(1.5)"), BUTTON_STYLE)
    css = Styles(get(tb.attributes, :style, Styles()), style)
    return jsrender(
        session,
        DOM.input(;
            type="checkbox",
            checked=tb.value,
            onchange=js"""event=> $(tb.value).notify(event.srcElement.checked);""",
            tb.attributes...,
            style=css
        ),
    )
end

# TODO, clean this up
const noUiSlider = ES6Module(dependency_path("nouislider.min.js"))
const noUiSliderCSS = Asset(dependency_path("noUISlider.css"))

function jsrender(session::Session, slider::RangeSlider)
    args = (slider.range, slider.connect, slider.orientation, slider.tooltips, slider.ticks)
    style = map(session, args...) do range, connect, orientation, tooltips, ticks
        value = slider.value[]
        return Dict(
            "range" => Dict("min" => range[1], "max" => range[end]),
            "step" => step(range),
            # Too strongly typed and we get a TypedArray in JS which doesn't work with noUiSlider
            "start" => Any[value...],
            "connect" => connect,
            "tooltips" => tooltips,
            "direction" => "ltr",
            "orientation" => string(orientation),
            "pips" => isempty(ticks) ? nothing : ticks,
        )
    end
    rangediv = DOM.div()
    create_slider = js"""
    function create_slider(style){
        const range = $(rangediv);
        range.noUiSlider.updateOptions(style, true);
    }"""
    onload(
        session,
        rangediv,
        js"""function onload(range){
    const style = $(style[]);
    $(noUiSlider).then(NUS=> {
        NUS.create(range, style);
        range.noUiSlider.on('update', function (values, handle, unencoded, tap, positions){
            $(slider.value).notify([parseFloat(values[0]), parseFloat(values[1])]);
        });
    })
}""",
    )
    onjs(session, style, create_slider)
    return DOM.div(jsrender(session, noUiSliderCSS), rangediv)
end

"""
A simple wrapper for types that conform to the Tables.jl Table interface,
which gets rendered nicely!
"""
struct Table
    table
    class::String
    row_renderer::Function  # For backwards compatibility - kept but deprecated
    class_callback::Function
    style_callback::Function
    allow_row_sorting::Bool
    allow_column_sorting::Bool
end

render_row_value(x) = x
render_row_value(x::Missing) = "n/a"
render_row_value(x::AbstractString) = string(x)
render_row_value(x::String) = x

# Default color callback - returns neutral for all cells
default_class_callback(table, row, col, val) = "table-cell cell-neutral"

function Table(table;
               class="",
               row_renderer=render_row_value,  # Kept for backwards compatibility
               class_callback=(args...) -> "cell-default",
               style_callback=(args...) -> "",
               allow_row_sorting=true,
               allow_column_sorting=true)
    return Table(table, class, row_renderer, class_callback, style_callback, allow_row_sorting, allow_column_sorting)
end

const TableStyles = Styles(
    CSS(
        ".comparison-table",
        "border-collapse" => "collapse",
        "width" => "100%",
        "font-family" => "Arial, sans-serif",
    ),
    CSS(
        ".table-header",
        "background-color" => "#f5f5f5",
        "border" => "1px solid #ddd",
        "padding" => "8px",
        "text-align" => "left",
        "font-weight" => "bold",
        "cursor" => "pointer",
        "user-select" => "none",
    ),
    CSS(
        ".table-header:hover",
        "background-color" => "#e9e9e9",
    ),
    CSS(
        ".table-cell",
        "border" => "1px solid #ddd",
        "padding" => "8px",
        "text-align" => "left",
    ),
    CSS(
        ".table-row:hover .table-cell",
        "background-color" => "#f9f9f9",
    ),
    CSS(
        ".cell-good",
        "background-color" => "#d4edda",
        "color" => "#155724",
    ),
    CSS(
        ".cell-bad",
        "background-color" => "#f8d7da",
        "color" => "#721c24",
    ),
    CSS(
        ".cell-neutral",
        "background-color" => "#fff3cd",
        "color" => "#856404",
    ),
    CSS(
        ".cell-default",
        "background-color" => "white",
        "color" => "black",
    ),
    CSS(
        ".table-container",
        "overflow-x" => "auto",
    ),
)

function jsrender(session::Session, table::Table)
    # Get table structure
    schema = Tables.schema(table.table)
    rows_data = collect(Tables.rows(table.table))

    # Get column names - handle case when schema is nothing
    column_names = if schema !== nothing && schema.names !== nothing
        schema.names
    elseif !isempty(rows_data)
        keys(first(rows_data))
    else
        ()  # Empty table
    end

    # Create header row with optional click handlers for column sorting
    header_cells = []
    for (col_idx, col_name) in enumerate(column_names)
        push!(header_cells, DOM.th(col_name; class = "table-header", dataColumn = col_idx - 1))
    end
    header_row = DOM.tr(header_cells...)

    # Create data rows
    data_rows = []
    for (row_idx, row) in enumerate(rows_data)
        cells = []
        for (col_idx, val) in enumerate(values(row))
            # Apply formatter callback (preferred) or fall back to row_renderer for backwards compatibility
            formatted_val = table.row_renderer(val)
            # Determine cell class using color callback
            cell_class = table.class_callback(table.table, row_idx, col_idx, val)
            style = table.style_callback(table.table, row_idx, col_idx, val)
            push!(cells, DOM.td(formatted_val; class = "table-cell $cell_class", dataValue = val, style=style))
        end
        push!(data_rows, DOM.tr(cells...; dataRow = row_idx-1, class="table-row"))
    end

    # Create the complete table
    table_dom = DOM.table(
        DOM.thead(header_row),
        DOM.tbody(data_rows...),
        class="comparison-table $(table.class)"
    )

    table_container = DOM.div(
        TableStyles,
        table_dom,
        class="table-container"
    )

    # JavaScript for interactive sorting
    sort_script = if table.allow_row_sorting || table.allow_column_sorting
        js"""
        (function() {
            const container = $(table_container);
            let sort_directions = {};
            const table = container.querySelector('.comparison-table');
            const tbody = table.querySelector('tbody');
            const thead = table.querySelector('thead');

            function sort_table_by_column(column_index) {
                if (!$(table.allow_column_sorting)) return;

                const current_direction = sort_directions['col_' + column_index] || 'asc';
                const new_direction = current_direction === 'asc' ? 'desc' : 'asc';
                sort_directions['col_' + column_index] = new_direction;

                const rows = Array.from(tbody.children);
                rows.sort((a, b) => {
                    const a_value = a.children[column_index].getAttribute('data-value');
                    const b_value = b.children[column_index].getAttribute('data-value');

                    if (!a_value || a_value === '') return 1;
                    if (!b_value || b_value === '') return -1;

                    const a_num = parseFloat(a_value);
                    const b_num = parseFloat(b_value);

                    let comparison = 0;
                    if (!isNaN(a_num) && !isNaN(b_num)) {
                        comparison = a_num - b_num;
                    } else {
                        comparison = a_value.localeCompare(b_value);
                    }

                    return new_direction === 'asc' ? comparison : -comparison;
                });

                tbody.innerHTML = '';
                rows.forEach(row => tbody.appendChild(row));
            }

            function sort_row_by_values(row_index) {
                if (!$(table.allow_row_sorting)) return;

                const current_direction = sort_directions['row_' + row_index] || 'asc';
                const new_direction = current_direction === 'asc' ? 'desc' : 'asc';
                sort_directions['row_' + row_index] = new_direction;

                const data_row = tbody.children[row_index];
                const header_row = thead.querySelector('tr');

                const cells = Array.from(data_row.children);
                const attribute_cell = cells[0];
                const data_cells = cells.slice(1);

                const header_cells = Array.from(header_row.children);
                const attribute_header = header_cells[0];
                const data_headers = header_cells.slice(1);

                const cell_header_pairs = data_cells.map((cell, idx) => ({
                    cell: cell,
                    header: data_headers[idx],
                    value: cell.getAttribute('data-value')
                }));

                cell_header_pairs.sort((a, b) => {
                    const a_value = a.value;
                    const b_value = b.value;

                    if (!a_value || a_value === '') return 1;
                    if (!b_value || b_value === '') return -1;

                    const a_num = parseFloat(a_value);
                    const b_num = parseFloat(b_value);

                    let comparison = 0;
                    if (!isNaN(a_num) && !isNaN(b_num)) {
                        comparison = a_num - b_num;
                    } else {
                        comparison = a_value.localeCompare(b_value);
                    }

                    return new_direction === 'asc' ? comparison : -comparison;
                });

                data_row.innerHTML = '';
                header_row.innerHTML = '';

                data_row.appendChild(attribute_cell);
                header_row.appendChild(attribute_header);

                cell_header_pairs.forEach(pair => {
                    data_row.appendChild(pair.cell);
                    header_row.appendChild(pair.header);
                });

                // Update all other rows to match the new column order
                Array.from(tbody.children).forEach((row, idx) => {
                    if (idx !== row_index) {
                        const row_cells = Array.from(row.children);
                        const row_attribute_cell = row_cells[0];
                        const row_data_cells = row_cells.slice(1);

                        const reordered_cells = cell_header_pairs.map(pair => {
                            const original_index = data_cells.indexOf(pair.cell);
                            return row_data_cells[original_index];
                        });

                        row.innerHTML = '';
                        row.appendChild(row_attribute_cell);
                        reordered_cells.forEach(cell => row.appendChild(cell));
                    }
                });
            }

            // Add column header click listeners
            if ($(table.allow_column_sorting)) {
                Array.from(thead.querySelectorAll('.table-header')).forEach((header, index) => {
                    header.addEventListener('click', function() {
                        sort_table_by_column(index);
                    });
                });
            }

            // Add row sorting listeners (first cell of each row)
            if ($(table.allow_row_sorting)) {
                Array.from(tbody.children).forEach((row, row_index) => {
                    const first_cell = row.children[0];
                    if (first_cell) {
                        first_cell.style.cursor = 'pointer';
                        first_cell.style.userSelect = 'none';
                        first_cell.addEventListener('click', function() {
                            sort_row_by_values(row_index);
                        });
                    }
                });
            }
        })();
        """
    else
        nothing
    end

    return jsrender(session, DOM.div(
        table_container,
        sort_script
    ))
end

struct CodeEditor
    theme::String
    language::String
    options::Dict{String,Any}
    onchange::Observable{String}
    element::Hyperscript.Node{Hyperscript.HTMLSVG}
end

"""
    CodeEditor(language::String; initial_source="", theme="chrome", editor_options...)

Defaults for `editor_options`:
```
(
    autoScrollEditorIntoView = true,
    copyWithEmptySelection = true,
    wrapBehavioursEnabled = true,
    useSoftTabs = true,
    enableMultiselect = true,
    showLineNumbers = false,
    fontSize = 16,
    wrap = 80,
    mergeUndoDeltas = "always"
)
```
The content of the editor (as a string) is updated in `editor.onchange::Observable`.
"""
function CodeEditor(
    language::String;
    height=500,
    initial_source="",
    theme="chrome",
    style=Styles(),
    editor_options...,
)
    defaults = Dict(
        "autoScrollEditorIntoView" => true,
        "copyWithEmptySelection" => true,
        "wrapBehavioursEnabled" => true,
        "useSoftTabs" => true,
        "enableMultiselect" => true,
        "showLineNumbers" => false,
        "fontSize" => 16,
        "vScrollBarAlwaysVisible" => false,
        "hScrollBarAlwaysVisible" => false,
        "wrap" => 80,
        "mergeUndoDeltas" => "always",
        "showGutter" => false,
        "highlightActiveLine" => false,
        "displayIndentGuides" => false,
        "showPrintMargin" => false,
    )
    user_opts = Dict{String,Any}(string(k) => v for (k, v) in editor_options)
    options = Dict{String,Any}(merge(defaults, user_opts))
    onchange = Observable(initial_source)
    style = Styles(style,
        "position" => "relative",
        "height" => "$(height)px",
    )
    element = DOM.div(""; style=style)
    return CodeEditor(theme, language, options, onchange, element)
end

function jsrender(session::Session, editor::CodeEditor)

    theme = "ace/theme/$(editor.theme)"
    language = "ace/mode/$(editor.language)"
    ace_url = "https://cdn.jsdelivr.net/gh/ajaxorg/ace-builds/src-min/ace.js"
    ace = DOM.script()
    onload(
        session,
        editor.element,
        js"""
            function (element){
                // sadly I cant find a way to use ace as an ES6 module, which means
                // we need to use more primitive methods, to make sure ace is loaded
                const onload_callback = () =>{
                    const editor = ace.edit(element, {
                        mode: $(language)
                    });
                    editor.setTheme($theme);
                    editor.getSession().setUseWrapMode(true)
                    // use setOptions method to set several options at once
                    editor.setOptions($(editor.options));

                    editor.session.on('change', function(delta) {
                        $(editor.onchange).notify(editor.getValue());
                    });
                    editor.session.setValue($(editor.onchange).value);
                    function resizeEditor() {
                        const height = editor.getSession().getScreenLength() *
                            (editor.renderer.lineHeight + editor.renderer.scrollBar.getWidth());
                        editor.container.style.height = `${height}px`;
                    }
                    // Resize the editor initially
                    resizeEditor();
                }
                const ace_script = $(ace)
                // we need to first set the onload callback and set the src afterwards!
                // I wish we could just make ACE an ES6 module, but haven't found a way yet
                ace_script.onload = onload_callback;
                ace_script.src = $(ace_url);
            }
        """,
    )
    return jsrender(session, DOM.div(ace, editor.element))
end

# Ok, this is bad piracy, but I donno how else to make the display nice for now!
function Base.show(io::IO, m::MIME"text/html", widget::WidgetsBase.AbstractWidget)
    return show(io, m, App(widget))
end


struct FileInput <: Bonito.WidgetsBase.AbstractWidget{String}
    value::Observable{Vector{String}}
    multiple::Bool
end

FileInput(value::Observable{Vector{String}}; multiple = true) = FileInput(Observable([""]), multiple)
FileInput(; kws...) = FileInput(Observable([""]); kws...)

function Bonito.jsrender(session::Session, fi::FileInput)
    onchange = js"""event => {
        if (event.target.files) {
            const files = [];
            for (const file of event.target.files) {
                files.push(URL.createObjectURL(file))
            }
            $(fi.value).notify(files);
        }
    }"""
    return DOM.input(; type="file", onchange=onchange, multiple=fi.multiple)
end

# ChoicesBox

const CHOICESBOX_EXAMPLE = """
App() do
    # Create a combo box with some sample options
    fruits = ["Apple", "Banana", "Cherry", "Date", "Elderberry", "Fig", "Grape"]

    # Configure Choices.js parameters
    params = ChoicesJSParams(
        searchPlaceholderValue="Type to search fruits...",
        searchEnabled=true,
        shouldSort=true,
        searchResultLimit=5
    )
    combobox = ChoicesBox(fruits;
        initial_value="Apple",
        choicejsparams=params
    )

    # Display selected value
    selected_display = map(combobox.value) do value
        isempty(value) ? "No selection" : "Selected: \$value"
    end

    # Handle value changes
    on(combobox.value) do value
        @info "ComboBox value changed to: \$value"
    end

    return DOM.div(
        DOM.h2("Choices.js ComboBox Example"),
        DOM.p("This combo box allows you to select from predefined options or type your own:"),
        combobox,
        DOM.p(selected_display, style="margin-top: 20px; font-weight: bold;")
    )
end

"""

# External JavaScript library assets
# https://github.com/Choices-js/Choices/blob/main/README.md
const ChoicesJS = ES6Module("https://cdn.jsdelivr.net/npm/choices.js/public/assets/scripts/choices.min.js")
const ChoicesCSS = Asset("https://cdn.jsdelivr.net/npm/choices.js/public/assets/styles/choices.min.css")

"""
    ChoicesJSParams(; kwargs...)

Wrapper struct for parameters to the ChoicesJS `Choices` constructor.

Parameters include search functionality, rendering options, and behavior settings
for the Choices.js library. See the official documentation for complete parameter
reference: https://github.com/Choices-js/Choices/blob/main/README.md

# Fields
- `addItems::Bool`: Allow adding of items (default: true)
- `itemSelectText::String`: Text shown when hovering over selectable items
- `placeholder::Bool`: Show placeholder text (default: true)
- `placeholderValue::String`: Placeholder text to display
- `removeItemButton::Bool`: Show remove button on items (default: false)
- `renderChoiceLimit::Int`: Limit choices rendered (-1 for no limit)
- `searchEnabled::Bool`: Enable search functionality (default: true)
- `searchPlaceholderValue::String`: Search input placeholder text
- `searchResultLimit::Int`: Limit search results (default: 4)
- `shouldSort::Bool`: Sort choices alphabetically (default: true)
"""
Base.@kwdef struct ChoicesJSParams
    addItems::Bool = true
    itemSelectText::String = "Press to select"
    placeholder::Bool = true
    placeholderValue::String = ""
    removeItemButton::Bool = false
    renderChoiceLimit::Int = -1
    searchEnabled::Bool = true
    searchPlaceholderValue::String = ""
    searchResultLimit::Int = 4
    shouldSort::Bool = true
end

function (c::ChoicesJSParams)()
    return js"""
    {
        addItems: $(c.addItems),
        itemSelectText: $(c.itemSelectText),
        placeholder: $(c.placeholder),
        placeholderValue: $(c.placeholderValue),
        removeItemButton: $(c.removeItemButton),
        renderChoiceLimit: $(c.renderChoiceLimit),
        searchEnabled: $(c.searchEnabled),
        searchPlaceholderValue: $(c.searchPlaceholderValue),
        searchResultLimit: $(c.searchResultLimit),
        shouldSort: $(c.shouldSort),
        // fixed params
        items: [],
        choices: []

    }
    """
end

"""
    ChoicesBox(options; initial_value="", choicejsparams=ChoicesJSParams(...), attributes...)

A combo box widget using the Choices.js library that allows both text input and selection from predefined options.
Users can either select from the dropdown list or type their own custom values.

# Fields
- `options::Observable{Vector{String}}`: Available dropdown options
- `value::Observable{String}`: Current selected or typed value
- `choicejsparams::ChoicesJSParams`: Choices.js configuration parameters
- `attributes::Dict{Symbol, Any}`: DOM attributes applied to the element

    ChoicesBox(options; initial_value="", choicejsparams=ChoicesJSParams(...), attributes...)

Constructor for creating a ChoicesBox widget.

# Arguments
- `options`: Vector or Observable of string options for the dropdown
- `initial_value=""`: Initial selected value
- `choicejsparams=ChoicesJSParams(searchPlaceholderValue="Type here...")`: Choices.js configuration
- `attributes...`: Additional DOM attributes

# Returns
- `ChoicesBox`: A configured combo box widget instance

# Example

```julia
$(CHOICESBOX_EXAMPLE)
```
"""
struct ChoicesBox
    options::Observable{Vector{String}}
    value::Observable{Union{Nothing,String}}
    choicejsparams::ChoicesJSParams
    attributes::Dict{Symbol, Any}
end


function ChoicesBox(options; choicejsparams = ChoicesJSParams(), attributes...)
    options = convert(Observable{Vector{String}}, options)
    value = Observable{Union{Nothing,String}}(nothing)

    return ChoicesBox(
        convert(Observable{Vector{String}}, options),
        value,
        choicejsparams,
        attributes
    )
end

function jsrender(session::Session, choicesbox::ChoicesBox)
    # Map options to option elements
    option_elements = map(choicesbox.options) do options
        return map(o->DOM.option(o, value = o), options)
    end
    selectDOM = map(opts->DOM.select(opts..., class = "choicesbox"), option_elements)[]

    # Choices.js initialization and event handling
    choices_script = js"""
        function initChoices(selectElement) {
            // Wait for Choices.js to load
            if (typeof Choices === 'undefined') {
                // console.log("Wait for Choices.js to load")
                setTimeout(() => initChoices(selectElement), 100);
                return;
            }
            const choices = new Choices(selectElement, $(choicesbox.choicejsparams()));

            // Handle value changes
            selectElement.addEventListener('change', function(event) {
                            console.log(choices.choices)

                // console.log("Handle value changes", event.detail.value || event.target.value)
                $(choicesbox.value).notify(event.detail.value || event.target.value);
            });


            // Update choices when options change
            $(choicesbox.options).on(function(newOptions) {
                // console.log("Update choices when options change", newOptions)
                choices.clearStore();
                newOptions.forEach(option => {
                    choices.setChoices([{value: option, label: option}], 'value', 'label', false);
                });
                $(choicesbox.value).notify(null);
            });

            // Update value when observable changes
            $(choicesbox.value).on(function(newValue) {
                // console.log("Update value when observable changes", newValue)
                if (choices.getValue(true) !== newValue) {
                    choices.setChoiceByValue(newValue);
                }
            });


        }

        initChoices($(selectDOM));
    """
    return Bonito.jsrender(session, DOM.div(ChoicesJS, ChoicesCSS, selectDOM, choices_script))
end
