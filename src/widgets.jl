using Observables

abstract type AbstractWidget{T} <: Observables.AbstractObservable{T} end

Observables.observe(x::AbstractWidget) = x.value

struct Button{T} <: AbstractWidget{Bool}
    content::Observable{T}
    value::Observable{Bool}
    attributes::Dict{Symbol, Any}
end

function Button(content; kw...)
    return Button(
        Observable(content), Observable(false), Dict{Symbol, Any}(kw)
    )
end

function jsrender(button::Button)
    return DOM.input(
        type = "button",
        value = button.content,
        onclick = js"update_obs($(button.value), true);";
        button.attributes...
    )
end

struct TextField <: AbstractWidget{String}
    value::Observable{String}
    attributes::Dict{Symbol, Any}
end

function TextField(value::String; kw...)
    TextField(Observable(value), Dict{Symbol, Any}(kw))
end

function jsrender(tf::TextField)
    return DOM.input(
        type = "textfield",
        value = tf.value,
        onchange = js"update_obs($(tf.value),  this.value);";
        tf.attributes...
    )
end

struct NumberInput <: AbstractWidget{Float64}
    value::Observable{Float64}
    attributes::Dict{Symbol, Any}
end

function NumberInput(value::Float64; kw...)
    NumberInput(Observable(value), Dict{Symbol, Any}(kw))
end

function jsrender(ni::NumberInput)
    return DOM.input(
        type = "number",
        value = ni.value,
        onchange = js"update_obs($(ni.value), parseFloat(this.value));";
        ni.attributes...
    )
end

struct Slider{T <: AbstractRange, ET} <: AbstractWidget{T}
    range::Observable{T}
    value::Observable{ET}
    attributes::Dict{Symbol, Any}
end

to_node(x) = Observable(x)
to_node(x::Observable) = x

function Slider(range::T, value = first(range); kw...) where T <: AbstractRange
    Slider{T, eltype(range)}(
        to_node(range),
        to_node(value),
        Dict{Symbol, Any}(kw)
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

@enum Orientation vertical horizontal

struct RangeSlider{T <: AbstractRange, ET <: AbstractArray} <: AbstractWidget{T}
    attributes::Dict{Symbol, Any}
    range::Observable{T}
    value::Observable{ET}
    connect::Observable{Bool}
    orientation::Observable{Orientation}
    tooltips::Observable{Bool}
    ticks::Observable{Dict{String, Any}}
end

function RangeSlider(range::T; value = [first(range)], kw...) where T <: AbstractRange
    RangeSlider{T, typeof(value)}(
        Dict{Symbol, Any}(kw),
        Observable(range),
        Observable(value),
        Observable(true),
        Observable(horizontal),
        Observable(false),
        Observable(Dict{String, Any}()),
    )
end


const noUiSlider = Dependency(
    :noUiSlider,
    [
        "https://cdn.jsdelivr.net/gh/leongersen/noUiSlider/distribute/nouislider.min.js",
        "https://cdn.jsdelivr.net/gh/leongersen/noUiSlider/distribute/nouislider.min.css"
    ]
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
        console.log(style);
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
