# Render the widgets from WidgetsBase.jl
function jsrender(session::Session, button::Button)
    return jsrender(session, DOM.button(
        button.content,
        onclick = js"event=> $(button.value).notify(true);";
        button.attributes...
    ))
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
        onchange = js"$(ni.value).notify(parseFloat(this.value));";
        ni.attributes...
    ))
end

function jsrender(session::Session, slider::Slider)
    return jsrender(session, DOM.input(
        type = "range",
        min = map(first, slider.range),
        max = map(last, slider.range),
        value = slider.value,
        step = map(step, slider.range),
        oninput = js"""(event)=> {
            $(slider.value).notify(parseFloat(event.srcElement.value))
        }""";
        slider.attributes...
    ))
end

function jsrender(session::Session, tb::Checkbox)
    return jsrender(session, DOM.input(
        type = "checkbox",
        checked = tb.value,
        onchange = js"""event=> $(tb.value).notify(event.srcElement.checked);""";
        tb.attributes...
    ))
end

# const noUiSlider = Dependency(
#     :noUiSlider,
#     [dependency_path("nouislider.min.js"), dependency_path("nouislider.min.css")]
# )

function jsrender(session::Session, slider::RangeSlider)
    args = (slider.range, slider.connect, slider.orientation,
            slider.tooltips, slider.ticks)
    style = map(session, args...) do range, connect, orientation, tooltips, ticks
        value = slider.value[]
        return Dict(
            "range" => Dict(
                "min" => fill(range[1], length(value)),
                "max" => fill(range[end], length(value)),
            ),
            "step" => step(range),
            "start" => value,
            "connect" => connect,
            "tooltips" => tooltips,
            "direction" => "ltr",
            "orientation" => string(orientation),
            "pips" => isempty(ticks) ? nothing : ticks
        )
    end
    rangediv = DOM.div()
    create_slider = js"""function create_slider(style){
        const range = $(rangediv);
        range.noUiSlider.updateOptions(style, true);
    }"""
    onload(session, rangediv, js"""function onload(range){
        const style = $(style[]);
        $(noUiSlider).create(range, style);
        range.noUiSlider.on('update', function (values, handle, unencoded, tap, positions){
            $(slider.value).notify([parseFloat(values[0]), parseFloat(values[1])]);
        });
    }""")
    onjs(session, style, create_slider)
    return rangediv
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
    return DOM.table(header, body; class=table.class)
end

# const ace = Dependency(
#     :ace,
#     ["https://cdn.jsdelivr.net/gh/ajaxorg/ace-builds/src-min/ace.js"]
# )

struct CodeEditor
    theme::String
    language::String
    options::Dict{Symbol, Any}
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
function CodeEditor(language::String; initial_source="", theme="chrome", editor_options...)
    defaults = Dict(
        :autoScrollEditorIntoView => true,
        :copyWithEmptySelection => true,
        :wrapBehavioursEnabled => true,
        :useSoftTabs => true,
        :enableMultiselect => true,
        :showLineNumbers => false,
        :fontSize => 16,
        :wrap => 80,
        :mergeUndoDeltas => "always"
    )
    options = Dict{Symbol, Any}(merge(Dict(editor_options), defaults))
    onchange = Observable(initial_source)
    element = DOM.div("", id="editor")
    return CodeEditor(theme, language, options, onchange, element)
end

function jsrender(session::Session, editor::CodeEditor)
    theme = "ace/theme/$(editor.theme)"
    language = "ace/mode/$(editor.language)"
    onload(session, editor.element, js"""
        function (element){
            var editor = $ace.edit(element);
            editor.setTheme($theme);
            editor.session.setMode($language);
            editor.resize();
            // use setOptions method to set several options at once
            editor.setOptions($(editor.options));

            editor.session.on('change', function(delta) {
                $(editor.onchange).notify(editor.getValue());
            });

            editor.session.setValue($(editor.onchange[]));
        }
    """)
    return editor.element
end

# Ok, this is bad piracy, but I donno how else to make the display nice for now!
function Base.show(io::IO, m::MIME"text/html", widget::WidgetsBase.AbstractWidget)
    show(io, m, App(widget))
end
