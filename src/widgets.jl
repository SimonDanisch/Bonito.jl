# Render the widgets from WidgetsBase.jl

function jsrender(button::Button)
    return DOM.input(
        type = "button",
        value = button.content,
        onclick = js"update_obs($(button.value), true);";
        button.attributes...
    )
end

function jsrender(tf::TextField)
    return DOM.input(
        type = "textfield",
        value = tf.value,
        onchange = js"update_obs($(tf.value),  this.value);";
        tf.attributes...
    )
end

function jsrender(ni::NumberInput)
    return DOM.input(
        type = "number",
        value = ni.value,
        onchange = js"update_obs($(ni.value), parseFloat(this.value));";
        ni.attributes...
    )
end

function jsrender(slider::Slider)
    return DOM.input(
        type = "range",
        min = map(first, slider.range),
        max = map(last, slider.range),
        value = slider.value,
        step = map(step, slider.range),
        oninput = js"update_obs($(slider.value), parseFloat(value))";
        slider.attributes...
    )
end

const noUiSlider = Dependency(
    :noUiSlider,
    [dependency_path("nouislider.min.js"), dependency_path("nouislider.min.css")]
)

function jsrender(session::Session, slider::RangeSlider)
    args = (slider.range, slider.connect, slider.orientation,
            slider.tooltips, slider.ticks)
    style = map(args...) do range, connect, orientation, tooltips, ticks
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
        var range = $(rangediv);
        range.noUiSlider.updateOptions(deserialize_js(style), true);
    }"""
    onload(session, rangediv, js"""function onload(range){
        var style = $(style[]);
        $(noUiSlider).create(range, style);
        range.noUiSlider.on('update', function (values, handle, unencoded, tap, positions){
            update_obs($(slider.value), [parseFloat(values[0]), parseFloat(values[1])]);
        });
    }""")
    onjs(session, style, create_slider)
    return rangediv
end

function JSServe.jsrender(tb::Checkbox)
    return DOM.input(
        type = "checkbox",
        checked = tb.value,
        onchange = js"update_obs($(tb.value), this.checked);";
        tb.attributes...
    )
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

function JSServe.jsrender(table::Table)
    names = string.(Tables.schema(table.table).names)
    header = DOM.thead(DOM.tr(DOM.th.(names)...))
    rows = []
    for row in Tables.rows(table.table)
        push!(rows, DOM.tr(DOM.th.(table.row_renderer.(values(row)))...))
    end
    body = DOM.tbody(rows...)
    return DOM.table(header, body; class=table.class)
end

const ace = JSServe.Dependency(
    :ace,
    ["https://cdn.jsdelivr.net/gh/ajaxorg/ace-builds/src-min/ace.js"]
)

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
    JSServe.onload(session, editor.element, js"""
        function (element){
            var editor = $ace.edit(element);
            editor.setTheme($theme);
            editor.session.setMode($language);
            editor.resize();
            // use setOptions method to set several options at once
            editor.setOptions($(editor.options));

            editor.session.on('change', function(delta) {
                update_obs($(editor.onchange), editor.getValue());
            });

            editor.session.setValue($(editor.onchange[]));
        }
    """)
    return editor.element
end

function jsrender(fp::FilePicker)
    return DOM.input(
        type = "file",
        value = fp.value,
        onchange = js"update_obs($(fp.value),  this.value);";
        fp.attributes...
    )
end
