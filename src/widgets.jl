# Render the widgets from WidgetsBase.jl

function jsrender(session::Session, button::Button)
    button_dom = DOM.button(
        button.content[],
        onclick=js"event=> $(button.value).notify(true);";
        button.attributes...
    )
    onjs(session, button.content, js"x=> $(button_dom).innerText = x")
    return jsrender(session, button_dom)
end

function jsrender(session::Session, tf::TextField)
    return jsrender(session, DOM.input(
        type = "textfield",
        value = tf.value,
        onchange = js"event => $(tf.value).notify(event.srcElement.value);";
        tf.attributes...
    ))
end

function jsrender(session::Session, ni::NumberInput)
    return jsrender(session, DOM.input(
        type = "number",
        value = ni.value,
        onchange=js"event => {
            const new_value = parseFloat(event.srcElement.value);
            if ($(ni.value).value != new_value) {
                $(ni.value).notify(new_value);
            }
        }";
        ni.attributes...
    ))
end

struct Slider{T} <: WidgetsBase.AbstractWidget{T}
    values::Observable{Vector{T}}
    value::Observable{T}
    index::Observable{Int}
    attributes::Dict{Symbol, Any}
end

function Slider(values::AbstractArray{T}; value=first(values), kw...) where {T}
    values_obs = convert(Observable{Vector{T}}, values)
    initial_idx = findfirst((==)(value), values_obs[])
    index = Observable(initial_idx)
    value_obs = map(getindex, values_obs, index)
    return Slider(values_obs, value_obs, index, Dict{Symbol, Any}(kw))
end

function jsrender(session::Session, slider::Slider)
    # Hacky, but don't want to Pr WidgetsBase yet
    values = slider.values
    index = slider.index
    onjs(session, index, js"""(index) => {
        const values = $(values).value
        $(slider.value).notify(values[index - 1])
    }
    """)
    return jsrender(session, DOM.input(
        type = "range",
        min = 1,
        max=map(length, values),
        value = index,
        step = 1,
        oninput = js"""(event)=> {
            $(index).notify(parseInt(event.srcElement.value))
        }""";
        slider.attributes...
    ))
end

function Base.setindex!(slider::Slider, value)
    # should be only numbers right now, which should also be sorted
    # This may change once we allow `Slider(array)` in WidgetsBase
    values = slider.values
    idx = findfirst(x-> x >= value, values[])

    if isnothing(idx)
        @warn("Value $(value) out of range for the values of slider (highest value: $(last(values[]))). Setting to highest value!")
        idx = length(values[])
    end
    slider.index[] = idx
    return idx
end

function jsrender(session::Session, tb::Checkbox)
    return jsrender(session, DOM.input(
        type = "checkbox",
        checked = tb.value,
        onchange = js"""event=> $(tb.value).notify(event.srcElement.checked);""";
        tb.attributes...
    ))
end
# TODO, clean this up
const noUiSlider = ES6Module(dependency_path("nouislider.min.js"))
const noUiSliderCSS = Asset(dependency_path("noUISlider.css"))

function jsrender(session::Session, slider::RangeSlider)
    args = (slider.range, slider.connect, slider.orientation,
            slider.tooltips, slider.ticks)
    style = map(session, args...) do range, connect, orientation, tooltips, ticks
        value = slider.value[]
        return Dict(
            "range" => Dict(
                "min" => range[1],
                "max" => range[end],
            ),
            "step" => step(range),
            # Too strongly typed and we get a TypedArray in JS which doesn't work with noUiSlider
            "start" => Any[value...],
            "connect" => connect,
            "tooltips" => tooltips,
            "direction" => "ltr",
            "orientation" => string(orientation),
            "pips" => isempty(ticks) ? nothing : ticks
        )
    end
    rangediv = DOM.div()
    create_slider = js"""
    function create_slider(style){
        const range = $(rangediv);
        range.noUiSlider.updateOptions(style, true);
    }"""
    onload(session, rangediv, js"""function onload(range){
        const style = $(style[]);
        $(noUiSlider).then(NUS=> {
            NUS.create(range, style);
            range.noUiSlider.on('update', function (values, handle, unencoded, tap, positions){
                $(slider.value).notify([parseFloat(values[0]), parseFloat(values[1])]);
            });
        })
    }""")
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

    return DOM.div(jsrender(session, Asset(dependency_path("table.css"))), DOM.table(header, body, class=table.class))
end

const ACE = ES6Module("https://cdn.jsdelivr.net/gh/ajaxorg/ace-builds/src-min/ace.js")

struct CodeEditor
    theme::String
    language::String
    options::Dict{String, Any}
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
function CodeEditor(language::String; width=500, height=500, initial_source="", theme="chrome", editor_options...)
    defaults = Dict(
        "autoScrollEditorIntoView" => true,
        "copyWithEmptySelection" => true,
        "wrapBehavioursEnabled" => true,
        "useSoftTabs" => true,
        "enableMultiselect" => true,
        "showLineNumbers" => false,
        "fontSize" => 16,
        "wrap" => 80,
        "mergeUndoDeltas" => "always"
    )
    user_opts = Dict{String, Any}(string(k) => v for (k,v) in editor_options)
    options = Dict{String, Any}(merge(user_opts, defaults))
    onchange = Observable(initial_source)
    style = """
        position: "absolute";
        top: 0;
        right: 0;
        bottom: 0;
        left: 0;
        width: $(width)px;
        height: $(height)px;
    """
    element = DOM.div(""; style=style)
    return CodeEditor(theme, language, options, onchange, element)
end

function jsrender(session::Session, editor::CodeEditor)
    theme = "ace/theme/$(editor.theme)"
    language = "ace/mode/$(editor.language)"
    onload(session, editor.element, js"""
        function (element){
            const editor = ace.edit(element, {
                mode: $(language)
            });
            editor.setTheme($theme);
            editor.resize();
            // use setOptions method to set several options at once
            editor.setOptions($(editor.options));

            editor.session.on('change', function(delta) {
                $(editor.onchange).notify(editor.getValue());
            });
            editor.session.setValue($(editor.onchange).value);
        }
    """)

    ace = DOM.script(src="https://cdn.jsdelivr.net/gh/ajaxorg/ace-builds/src-min/ace.js")
    return DOM.div(ace, editor.element)
end

# Ok, this is bad piracy, but I donno how else to make the display nice for now!
function Base.show(io::IO, m::MIME"text/html", widget::WidgetsBase.AbstractWidget)
    show(io, m, App(widget))
end

struct Dropdown
    options::Observable{Vector{Any}}
    value::Observable{Any}
    option_to_string::Function
    option_index::Observable{Int}
    attributes::Dict{Symbol, Any}
end

function Dropdown(options; index=1, option_to_string=string, attributes...)
    option_index = convert(Observable{Int}, index)
    options = convert(Observable{Vector{Any}}, options)
    option = Observable{Any}(options[][option_index[]])
    onany(option_index, options) do index, options
        option[] = options[index]
        return
    end
    return Dropdown(options, option, option_to_string, option_index, Dict{Symbol,Any}(attributes))
end

function jsrender(session::Session, dropdown::Dropdown)
    onchange = js"""
    function onload(element) {
        function onchange(e) {
            if (element === e.srcElement) {
                ($(dropdown.option_index)).notify(element.selectedIndex + 1);
            }
        }
        element.addEventListener("change", onchange);
        element.selectedIndex = $(dropdown.option_index[] - 1)
    }
    """
    option2div(x) = DOM.option(dropdown.option_to_string(x))
    dom = map(options -> map(option2div, options), session, dropdown.options)[]
    select = DOM.select(dom; dropdown.attributes...)
    JSServe.onload(session, select, onchange)
    return select
end


struct FileInput <: JSServe.WidgetsBase.AbstractWidget{String}
    value::Observable{Vector{String}}
end

FileInput() = FileInput(Observable([""]))

function JSServe.jsrender(session::Session, fi::FileInput)
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
