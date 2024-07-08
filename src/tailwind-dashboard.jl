module TailwindDashboard

import ..Bonito
import ..Bonito: DOM, Session, Observable, @js_str, Asset
using Hyperscript
const TailwindMini = Asset(Bonito.dependency_path("tailwind.min.css"))

FlexGrid(elems...; class="", kwargs...) = DOM.div(elems...; class=join(["flex flex-wrap", class], " "), kwargs...)
Grid(elems...; class="", kwargs...) = DOM.div(elems...; class=join(["grid ", class], " "), kwargs...)

function FlexRow(args...; class="", attributes...)
    return DOM.div(
        TailwindMini,
        args...;
        attributes...,
        class="mx-2 flex flex-row $class",
    )
end

function FlexCol(args...; class="", attributes...)
    return DOM.div(
        TailwindMini,
        args...;
        attributes...,
        class="my-2 flex flex-col $class",
    )
end

function Card(content; class="", style="", width="fit-content", height="fit-content", attributes...)
    return DOM.div(
        TailwindMini,
        content;
        style="width: $(width); height: $(height); $(style)",
        class="rounded-md p-2 m-2 shadow $class",
        attributes...
    )
end

function WidgetContainer(title, widget; class="", attributes...)
    return DOM.div(title, widget; class="flex-row, mb-1 mt-1 $class", attributes...)
end

function Title(name; class="", attributes...)
    return DOM.h2(name; class="font-semibold $class", attributes...)
end

struct Slider
    widget::Bonito.Slider
    dom::Hyperscript.Node{Hyperscript.HTMLSVG}
end

function Slider(name, values::AbstractArray; container_class="", attributes...)
    s = Bonito.Slider(values; style="width: 100%;", attributes...)
    title = Title(DOM.div(name, DOM.div(s.value; class="float-right text-right text w-32")))
    return Slider(s, WidgetContainer(title, s; class=container_class))
end
Bonito.jsrender(session::Session, x::Slider) = Bonito.jsrender(session, x.dom)

Bonito.is_widget(::Slider) = true
Bonito.value_range(slider::Slider) = Bonito.value_range(slider.widget)
Bonito.update_value!(slider::Slider, idx) = Bonito.update_value!(slider.widget, idx)
Bonito.to_watch(slider::Slider) = Bonito.to_watch(slider.widget)

struct Dropdown
    widget::Bonito.Dropdown
    dom::Hyperscript.Node{Hyperscript.HTMLSVG}
end

function Dropdown(name, values::AbstractArray; class="", container_class="", attributes...)
    class = "$class focus:outline-none focus:shadow-outline focus:border-blue-300 bg-white bg-gray-100 hover:bg-white text-gray-800 font-semibold m-1 py-1 px-3 border border-gray-400 rounded shadow"
    dd = Bonito.Dropdown(values; class=class, attributes...)
    return Dropdown(dd, WidgetContainer(Title(name), dd; class=container_class))
end

Bonito.jsrender(session::Session, x::Dropdown) = Bonito.jsrender(session, x.dom)

Bonito.is_widget(::Dropdown) = true
Bonito.value_range(dropdown::Dropdown) = Bonito.value_range(dropdown.widget)
Bonito.update_value!(dropdown::Dropdown, idx) = Bonito.update_value!(dropdown.widget, idx)
Bonito.to_watch(dropdown::Dropdown) = Bonito.to_watch(dropdown.widget)

struct Checkbox
    widget::Bonito.Checkbox
    dom::Hyperscript.Node{Hyperscript.HTMLSVG}
end

function Checkbox(name, value::Bool; container_class="", attributes...)
    c = Bonito.Checkbox(value; attributes...)
    return Checkbox(c, WidgetContainer(Title(name), c; class=container_class))
end
Bonito.jsrender(session::Session, x::Checkbox) = Bonito.jsrender(session, x.dom)

Bonito.is_widget(::Checkbox) = true
Bonito.value_range(checkbox::Checkbox) = Bonito.value_range(checkbox.widget)
Bonito.update_value!(checkbox::Checkbox, idx) = Bonito.update_value!(checkbox.widget, idx)
Bonito.to_watch(checkbox::Checkbox) = Bonito.to_watch(checkbox.widget)

function Button(name; class="", attributes...)
    class = "$class focus:outline-none focus:shadow-outline focus:border-blue-300 bg-white bg-gray-100 hover:bg-white text-gray-800 font-semibold m-1 py-1 px-3 border border-gray-400 rounded shadow"
    return Bonito.Button(name; class=class, style=Bonito.Styles("min-width" => "8rem"), attributes...)
end

function TextField(content::String; class="", attributes...)
    class = "$class focus:outline-none focus:shadow-outline focus:border-blue-300 bg-white bg-gray-100 hover:bg-white text-gray-800 font-semibold m-1 py-1 px-3 border border-gray-400 rounded shadow"
    return Bonito.TextField(string(content); class=class, attributes...)
end

function NumberInput(number::Number; class="", attributes...)
    class = "$class focus:outline-none focus:shadow-outline focus:border-blue-300 bg-white bg-gray-100 hover:bg-white text-gray-800 font-semibold m-1 py-1 px-3 border border-gray-400 rounded shadow"
    return Bonito.NumberInput(number; class=class, attributes...)
end


Base.getproperty(x::Dropdown, f::Symbol) = f === :value ? x.widget.value : f === :option_index ? x.widget.option_index : getfield(x, f)
Base.getproperty(x::Checkbox, f::Symbol) = f === :value ? x.widget.value : getfield(x, f)
Base.getproperty(x::Slider, f::Symbol) = f === :value ? x.widget.value : getfield(x, f)

function FileInput()
    container_class = "flex justify-center"
    inner_class = "mb-3 w-96"
    label_class = "form-label inline-block mb-2 text-gray-700"
    input_class = "form-control
    block
    w-full
    py-1.5
    text-base
    font-normal
    text-gray-700
    bg-white bg-clip-padding
    border border-solid border-gray-300
    rounded
    transition
    ease-in-out
    m-0
    focus:text-gray-700 focus:bg-white focus:border-blue-600 focus:outline-none"
    label = DOM.label("Input"; )
    Hyperscript.attrs(label)["for"] = "formFile"

    return Bonito.FileInput()
end

end
using ..TailwindDashboard
