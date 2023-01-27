module TailwindDashboard

import ..JSServe
import ..JSServe: DOM, Session, Observable, @js_str
using Hyperscript

function FlexRow(args...; class="", attributes...)
    return DOM.div(
        JSServe.TailwindCSS,
        args...;
        attributes...,
        class="m-2 flex flex-row $class",
    )
end

function FlexCol(args...; class="", attributes...)
    return DOM.div(
        JSServe.TailwindCSS,
        args...;
        attributes...,
        class="m-2 flex flex-col $class",
    )
end

function Card(content; class="", width="fit-content", height="fit-content", attributes...)
    return DOM.div(
        JSServe.TailwindCSS,
        content;
        style="width: $(width); height: $(height)",
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
    widget::JSServe.Slider
    dom::Hyperscript.Node{Hyperscript.HTMLSVG}
end

function Slider(name, values::AbstractArray; container_class="", attributes...)
    s = JSServe.Slider(values; style="width: 100%;", attributes...)
    title = Title(DOM.div(name, DOM.div(s.value; class="float-right")))
    return Slider(s, WidgetContainer(title, s; class=container_class))
end
JSServe.jsrender(session::Session, x::Slider) = JSServe.jsrender(session, x.dom)


struct Dropdown
    widget::JSServe.Dropdown
    dom::Hyperscript.Node{Hyperscript.HTMLSVG}
end

function Dropdown(name, values::AbstractArray; class="", container_class="", attributes...)
    class = "$class focus:outline-none focus:shadow-outline focus:border-blue-300 bg-white bg-gray-100 hover:bg-white text-gray-800 font-semibold m-1 py-1 px-3 border border-gray-400 rounded shadow"
    dd = JSServe.Dropdown(values; class=class, attributes...)
    return Dropdown(dd, WidgetContainer(Title(name), dd; class=container_class))
end

JSServe.jsrender(session::Session, x::Dropdown) = JSServe.jsrender(session, x.dom)

struct Checkbox
    widget::JSServe.Checkbox
    dom::Hyperscript.Node{Hyperscript.HTMLSVG}
end

function Checkbox(name, value::Bool; container_class="", attributes...)
    c = JSServe.Checkbox(value; attributes...)
    return Checkbox(c, WidgetContainer(Title(name), c; class=container_class))
end
JSServe.jsrender(session::Session, x::Checkbox) = JSServe.jsrender(session, x.dom)

function Button(name; class="", attributes...)
    class = "$class focus:outline-none focus:shadow-outline focus:border-blue-300 bg-white bg-gray-100 hover:bg-white text-gray-800 font-semibold m-1 py-1 px-3 border border-gray-400 rounded shadow"
    return JSServe.Button(name; class=class, style="min-width: 8rem;", attributes...)
end

function TextField(content::String; class="", attributes...)
    class = "$class focus:outline-none focus:shadow-outline focus:border-blue-300 bg-white bg-gray-100 hover:bg-white text-gray-800 font-semibold m-1 py-1 px-3 border border-gray-400 rounded shadow"
    return JSServe.TextField(string(content); class=class, attributes...)
end

function NumberInput(number::Number; class="", attributes...)
    class = "$class focus:outline-none focus:shadow-outline focus:border-blue-300 bg-white bg-gray-100 hover:bg-white text-gray-800 font-semibold m-1 py-1 px-3 border border-gray-400 rounded shadow"
    return JSServe.NumberInput(number; class=class, attributes...)
end


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

    return JSServe.FileInput()
end

end
using ..TailwindDashboard
