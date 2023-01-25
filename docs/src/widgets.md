# Widgets



## Editor

This editor works in pure Javascript, so feel free to try out editing the Javascript and clicking `eval` to see how the output changes.
In `JSServe/examples/editor.jl`, you will find a version that works with Julia code, but that requires a running Julia server of course.

```@setup 1
using JSServe
Page()
```

```@example 1
using JSServe
import JSServe.TailwindDashboard as D

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
    table = JSServe.Table([(a=22, b=33, c=44), (a=22, b=33, c=44)])

    source = """
    function test(a, b)
        return a + b
    end
    """
    editor = CodeEditor("julia"; initial_source=source, width=250, height=200, scrollPastEnd=false)
    dropdown = D.Dropdown("chose", ["option 1", "option 2", "option 3"])

    vrange_slider = range_slider(JSServe.WidgetsBase.vertical)

    hrange_slider = range_slider(JSServe.WidgetsBase.horizontal)


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
                D.Card(table; class="w-64")),
            D.FlexRow(
                D.Card.([
                    DOM.div(vrange_slider; style="height: 200px; padding: 1px 50px"),
                    DOM.div(hrange_slider; style="width: 200px; padding: 50px 1px"),
                    editor
                ])
            ),
        ])...
    )
end
```

```@example 1
using JSServe, Observables
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
    JSServe.onjs(session, eval_button.value, js"""function (click){
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
        JSServe.update_or_replace($(output), dom, false);
        return
    }
    """)
    notify(eval_button.value)
    return DOM.div(editor, eval_button, output)
end
```
