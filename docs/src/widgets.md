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

```@docs; canonical=false
Bonito.Table
```

The `Table` widget provides an interactive way to display tabular data that conforms to the Tables.jl interface.
It supports custom styling, interactive sorting, and flexible cell rendering.

### Basic Usage

```@example 1

# Create sample data using named tuples
data = [
    (name="Alice", age=25, score=95.5),
    (name="Bob", age=30, score=87.2),
    (name="Charlie", age=22, score=92.8)
]

# Basic table
basic_table = Bonito.Table(data)
App(basic_table)
```

### Custom Cell Styling

You can provide custom class and style callbacks to control the appearance of individual cells:

```@example 1
# Color coding function based on values
function score_class_callback(table, row, col, val)
    # Color the score column based on value
    if col == 3 && isa(val, Number)  # Score column
        if val >= 90
            return "cell-good"
        elseif val >= 80
            return "cell-neutral"
        else
            return "cell-bad"
        end
    end
    return "cell-default"
end

# Style callback for additional formatting
function score_style_callback(table, row, col, val)
    if col == 3 && isa(val, Number)  # Score column
        return "font-weight: bold;"
    end
    return ""
end

styled_table = Bonito.Table(data;
                    class_callback=score_class_callback,
                    style_callback=score_style_callback)
App(styled_table)
```

### Sorting Options

Tables support interactive sorting by clicking on headers (column sorting) or first cells (row sorting):

```@example 1
# Table with only column sorting enabled
column_sort_table = Bonito.Table(data;
                         allow_row_sorting=false,
                         allow_column_sorting=true)

# Table with all sorting disabled
no_sort_table = Bonito.Table(data;
                     allow_row_sorting=false,
                     allow_column_sorting=false)
App() do
    DOM.div(column_sort_table, no_sort_table)
end
```

### Working with DataFrames

The Table widget works seamlessly with DataFrames and other Tables.jl-compatible structures:

```@example 1
using DataFrames

df = DataFrame(
    Product = ["Laptop", "Mouse", "Keyboard", "Monitor"],
    Price = [999.99, 29.99, 79.99, 299.99],
    Stock = [15, 120, 45, 8],
    Available = [true, true, false, true]
)

# Custom formatter for currency and boolean values
function product_class_callback(table, row, col, val)
    if col == 2  # Price column
        return val > 100 ? "cell-neutral" : "cell-good"
    elseif col == 4  # Available column
        return val ? "cell-good" : "cell-bad"
    end
    return "cell-default"
end

product_table = Bonito.Table(df; class_callback=product_class_callback)
App(product_table)
```

### Advanced Example: Financial Data

```@example 1
# Financial data with multiple metrics
financial_data = [
    (company="TechCorp", revenue=1.2e6, profit_margin=0.15, employees=150),
    (company="DataInc", revenue=2.8e6, profit_margin=0.08, employees=300),
    (company="CloudSys", revenue=0.9e6, profit_margin=0.22, employees=85),
    (company="WebFlow", revenue=1.8e6, profit_margin=0.12, employees=220)
]

function financial_class_callback(table, row, col, val)
    if col == 2  # Revenue column
        return val > 1.5e6 ? "cell-good" : "cell-neutral"
    elseif col == 3  # Profit margin column
        if val > 0.15
            return "cell-good"
        elseif val > 0.10
            return "cell-neutral"
        else
            return "cell-bad"
        end
    end
    return "cell-default"
end

function financial_style_callback(table, row, col, val)
    if col == 3  # Profit margin column
        return "font-family: monospace;"
    end
    return ""
end

financial_table = Bonito.Table(financial_data;
                       class_callback=financial_class_callback,
                       style_callback=financial_style_callback,
                       class="financial-data")
App(financial_table)
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
