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
    range::Observable{T}
    value::Observable{ET}
    attributes::Dict{Symbol, Any}
    connect::Observable{Bool}
    orientation::Observable{Orientation}
end

function RangeSlider(range::T; value = [first(range)], kw...) where T <: AbstractRange
    RangeSlider{T, typeof(value)}(
        Observable(range),
        Observable(value),
        Dict{Symbol, Any}(kw),
        Observable(true),
        Observable(horizontal)
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
    rangediv = DOM.div()
    onload(session, rangediv, js"""
        function create_slider(range){
            $(noUiSlider).create(range, {

                range: {
                    'min': $(fill(slider.range[][1], length(slider.value[]))),
                    'max': $(fill(slider.range[][end], length(slider.value[])))
                },

                step: $(step(slider.range[])),

                // Handles start at ...
                start: $(slider.value[]),
                // Display colored bars between handles
                connect: $(slider.connect[]),
                tooltips: true,

                // Put '0' at the bottom of the slider
                direction: 'ltr',
                orientation: $(string(slider.orientation[])),
            });

            range.noUiSlider.on('update', function (values, handle, unencoded, tap, positions){
                update_obs($(slider.value), [parseFloat(values[0]), parseFloat(values[1])]);
            });
        }
    """)
    return rangediv
end
