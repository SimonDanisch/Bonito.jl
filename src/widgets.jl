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

A simple button, which can be styled a `style::Styles`.

### Example

```julia
$(BUTTON_EXAMPLE)
```
"""
Button

function jsrender(session::Session, button::Button)
    css = Styles(get(button.attributes, :style, Styles()), BUTTON_STYLE)
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

A simple TextField, which can be styled via the `style::Styles` attribute.

### Example

```julia
$(TEXTFIELD_EXAMPLE)
```
"""
TextField

function jsrender(session::Session, tf::TextField)
    css = Styles(get(tf.attributes, :style, Styles()), BUTTON_STYLE)
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

A simple NumberInput, which can be styled via the `style::Styles` attribute.

### Example

```julia
$(NUMBERINPUT_EXAMPLE)
```
"""
NumberInput

function jsrender(session::Session, ni::NumberInput)
    css = Styles(get(ni.attributes, :style, Styles()), BUTTON_STYLE)
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

A simple Dropdown, which can be styled via the `style::Styles` attribute.

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
    css = Styles(style, BUTTON_STYLE)
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
    value_obs = map(getindex, values_obs, index)
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
              $(index).notify(parseInt(event.srcElement.value))
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
    row_renderer::Function
end

render_row_value(x) = x
render_row_value(x::Missing) = "n/a"
render_row_value(x::AbstractString) = string(x)
render_row_value(x::String) = x

function Table(table; class="", row_renderer=render_row_value)
    return Table(table, class, row_renderer)
end

function jsrender(session::Session, table::Table)
    names = string.(Tables.schema(table.table).names)
    header = DOM.thead(DOM.tr(DOM.th.(names)...))
    rows = []
    for row in Tables.rows(table.table)
        push!(rows, DOM.tr(DOM.td.(table.row_renderer.(values(row)))...))
    end
    body = DOM.tbody(rows...)

    return DOM.div(
        jsrender(session, Asset(dependency_path("table.css"))),
        DOM.table(header, body; class=table.class),
    )
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
        "fontSize" => "1rem",
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
    options = Dict{String,Any}(merge(user_opts, defaults))
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
    ace = DOM.script(; src="https://cdn.jsdelivr.net/gh/ajaxorg/ace-builds/src-min/ace.js")

    onload(
        session,
        editor.element,
        js"""
            function (element){
                // sadly I cant find a way to use ace as an ES6 module, which means
                // we need to use more primitive methods, to make sure ace is loaded
                const ace_script = $(ace)
                ace_script.onload = function () {
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
end

FileInput() = FileInput(Observable([""]))

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
    return DOM.input(; type="file", onchange=onchange, multiple=true)
end
