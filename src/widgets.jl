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
