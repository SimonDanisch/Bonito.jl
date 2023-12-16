# Widgets

```@setup 1
using Bonito
Page()
```

## All Available widgets

```@docs; canonical=false
Button
```

```@example 1
include_string(@__MODULE__, Bonito.BUTTON_EXAMPLE) # hide
```

```@docs; canonical=false
TextField
```
```@example 1
include_string(@__MODULE__, Bonito.TEXTFIELD_EXAMPLE) # hide
```

```@docs; canonical=false
NumberInput
```
```@example 1
include_string(@__MODULE__, Bonito.NUMBERINPUT_EXAMPLE) # hide
```

```@docs; canonical=false
Dropdown
```
```@example 1
include_string(@__MODULE__, Bonito.DROPDOWN_EXAMPLE) # hide
```

```@docs
Card
```
```@example 1
include_string(@__MODULE__, Bonito.CARD_EXAMPLE) # hide
```

```@docs
StylableSlider
```
```@example 1
include_string(@__MODULE__, Bonito.STYLABLE_SLIDER_EXAMPLE) # hide
```


## Widgets in Layouts


There are a few helpers to e.g. put a label next to a widget:


```@docs
Labeled
```
```@example 1
include_string(@__MODULE__, Bonito.LABELED_EXAMPLE) # hide
```

To create more complex layouts, one should use e.g. [`Grid`](@ref), and visit the [Layouting](@ref) tutorial.


```@example 1

App() do session
    s = Bonito.StylableSlider(0:10;)
    d = Dropdown(["a", "b", "c"])
    ni = NumberInput(10.0)
    ti = Bonito.TextField("helo")
    button = Button("click")
    clicks = Observable(0)
    on(session, button.value) do bool
        clicks[] = clicks[] + 1
    end
    return Card(Grid(
            button, Bonito.Label(clicks),
            s, Bonito.Label(s.value),
            d, Bonito.Label(d.value),
            ni, Bonito.Label(ni.value),
            ti, Bonito.Label(ti.value);
            columns="1fr min-content",
            justify_content="begin",
            align_items="center",
        ); width="300px",)
end
```

## Editor

This editor works in pure Javascript, so feel free to try out editing the Javascript and clicking `eval` to see how the output changes.
In `Bonito/examples/editor.jl`, you will find a version that works with Julia code, but that requires a running Julia server of course.


```@example 1
using Bonito, Observables
src = """
(() => {
    const canvas = document.createElement("canvas");
    const context = canvas.getContext('2d');
    const width = 500
    const height = 400
    canvas.width = width;
    canvas.height = height;
    const gradient = context.createRadialGradient(200, 200, 0, 200, 200, 200);
    gradient.addColorStop("0", "magenta");
    gradient.addColorStop(".25", "blue");
    gradient.addColorStop(".50", "green");
    gradient.addColorStop(".75", "yellow");
    gradient.addColorStop("1.0", "red");
    context.fillStyle = gradient;
    context.fillRect(0, 0, width, height);
    return canvas;
})();
"""
App() do session::Session
    editor = CodeEditor("javascript"; initial_source=src, width=800, height=300)
    eval_button = Button("eval")
    output = DOM.div(DOM.span())
    Bonito.onjs(session, eval_button.value, js"""function (click){
        const js_src = $(editor.onchange).value;
        const result = new Function("return " + (js_src))()
        let dom;
        if (typeof result === 'object' && result.nodeName) {
            dom = result
        } else {
            const span = document.createElement("span")
            span.innerText = result;
            dom = span
        }
        Bonito.update_or_replace($(output), dom, false);
        return
    }
    """)
    notify(eval_button.value)
    return DOM.div(editor, eval_button, output)
end
```

## Tailwinddashboard

[`Styles`](@ref) is preferred to style components, but Bonito also includes some [Tailwind](https://tailwindcss.com/) based components.
They're from before `Styles` and will likely get removed in the future.


```@example 1
using Bonito
import Bonito.TailwindDashboard as D

function range_slider(orientation)
    range_slider = RangeSlider(1:100; value=[10, 80])
    range_slider.tooltips[] = true
    range_slider.ticks[] = Dict(
        "mode" => "range",
        "density" => 3
    )
    range_slider.orientation[] = orientation
    return range_slider
end

App() do

    button = D.Button("click")
    textfield = D.TextField("type in your text")
    numberinput = D.NumberInput(0.0)
    file_input = D.FileInput()
    on(file_input.value) do file
        @show file
    end
    slider = D.Slider("Test", 1:5)

    checkbox = D.Checkbox("check this", true)
    table = Bonito.Table([(a=22, b=33, c=44), (a=22, b=33, c=44)])

    source = """
    function test(a, b)
        return a + b
    end
    """
    editor = CodeEditor("julia"; initial_source=source, width=250, height=200, scrollPastEnd=false)
    dropdown = D.Dropdown("chose", ["option 1", "option 2", "option 3"])

    vrange_slider = range_slider(Bonito.WidgetsBase.vertical)

    hrange_slider = range_slider(Bonito.WidgetsBase.horizontal)


    return DOM.div(
        D.Card.([
            D.FlexRow(
                D.Card(D.FlexCol(
                    button,
                    textfield,
                    numberinput,
                    dropdown,
                    file_input,
                    slider,
                    checkbox,
                    class="items-start"
                )),
                D.Card(D.FlexCol(
                    D.Card(DOM.div(vrange_slider; style="height: 200px; padding: 1px 50px")),
                    D.Card(DOM.div(hrange_slider; style="width: 200px; padding: 50px 1px"),
                    )),
                )),
            D.FlexRow(
                D.Card.([

                    D.Card(table; class="w-64")
                    editor
                ])
            ),
        ])...
    )
end
```
