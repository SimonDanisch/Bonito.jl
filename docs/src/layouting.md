# Layouting


The main Layouting primitive JSServe offers is `Grid`, `Column` and `Row`.
They are all based on css `display: grid` and JSServe only offers a small convenience wrapper around it.

We recommend to read through the great introduction to Styles grids by Josh Comeau: https://www.joshwcomeau.com/css/interactive-guide-to-grid, for a better understanding on how grids work. It's recommended to read this before following this tutorial, since the examples are styled much nicer and explain everything in much greater detail.

To easier apply the tutorial to JSServe, we ported all the examples of the tutorial, while only describing them with the bare minimum. To get the full picture, please refer to the linked, original tutorial!

Lets start with the docstring for `Grid`:

```@docs
Grid
```

It pretty much just sets the css attributes to some defaults, but everything can be overwritten or extended by passing your own `style=Styles(...)` object.
All Styles objects inside one App will be merged into a single stylesheet, so using many grids with the same keyword arguments will only generate one entry into the global stylesheet. You can read more about this in the styling section.



```@setup 1
using JSServe
Page()
```

## Implicit Grids

If we don't speficy any attributes for the `Grid`, the default will be one dynamic column, where every item gets their own row:

```@example 1

DemoCard(content=DOM.div(); style=Styles(), attributes...) = Card(content; backgroundcolor=:gray, border_radius="2px", style=Styles(style, "color" => :white),attributes...)

App() do sess
    s = JSServe.Slider(1:5)
    cards = map(s.value) do n
        cards = [DemoCard(height="50px", width="300px") for i in 1:n]
        return Grid(cards;)
    end
    return JSServe.record_states(sess, Grid(s, cards))
end
```

If we specify a height, while not specifiying a height for the elements, the space will be partitioned for the n children:

```@example 1
App() do sess
    s = JSServe.Slider(1:5)
    cards = map(s.value) do n
        cards = [DemoCard(width="300px") for i in 1:n]
        Grid(cards; height="300px")
    end
    return JSServe.record_states(sess, Grid(s, cards))
end
```

To introduce new columns, we can specify a width for each column via the `column` keyword, which supports any css unit:

```@example 1
App() do
    grid = Grid(DemoCard(), DemoCard();
        height="300px", columns="25% 75%")
    return grid
end
```

Grid also introduced a new css unit namely `fr`, which represents the fraction of the leftover space in the grid container.

To see what that means, the below example shows how the percent based unit will shrink proportionally, while `fr` divides the space more evenly and can take the size of the content into it's constraint solver:

```@example 1
App() do sess
    container_width = JSServe.Slider(5:0.1:100)
    container_width[] = 100
    imstyle = Styles(
        "display" => :block, "position" => :relative, "width" => "100px",
        "max-width" => :none # needs to be set so it's not overwritten by others
    )
    img = DOM.img(; src="https://docs.makie.org/stable/assets/makie_logo_transparent.svg", style=imstyle)
    style = Styles("position" => :relative, "background-color" => :gray, "display" => :flex, "justify-content" => :center, "align-items" => :center)

    function example_grid(cols)
        grid = Grid(DemoCard(img; style=style), DemoCard(DOM.div(); style=style); columns=cols)
        container = DOM.div(grid; style=Styles("height" => "200px", "width" => "500px"))
        return Grid(container; rows="1fr", justify_content="center"), container
    end
    pgrid, p1 = example_grid("25% 75%")
    frgrid, p2 = example_grid("1fr 3fr")
    grid_percent = DOM.div(Grid(pgrid; rows="1fr"))
    grid_fr = DOM.div(Grid(frgrid; rows="1fr"))

    onjs(sess, container_width.value, js"w=> {$(p1).style.width = (5 * w) + 'px';}")
    onjs(sess, container_width.value, js"w=> {$(p2).style.width = (5 * w) + 'px';}")
    title_percent = DOM.h2("Grid(...; columns=\"25% 75%\")")
    title_fr = DOM.h2("Grid(...; columns=\"1fr 3fr\")")
    return Grid(container_width, title_percent, grid_percent, title_fr, grid_fr; columns="1fr")
end
```

Now, what happens if we add more then 2 items to a Grid with 2 columns?


```@example 1

# Little helper to create a Card with centered content
centered(c; style=Styles(), kw...) = DemoCard(Grid(DOM.h4(c; style=Styles("color" => :white)); justify_content=:center, justify_items=:center, columns="1fr", style=Styles("align-items"=> :center), kw...); style=style)


App() do
    cards = [centered(i) for i in 1:3]
    grid = Grid(cards...; columns="1fr 3fr")
    return DOM.div(grid; style=Styles("margin" => "20px"))
end
```

Specifying the size of the rows works exactly the same as with `columns`:

```@example 1
App() do
    cards = [centered(i) for i in 1:4]
    grid = Grid(cards...; columns="1fr 3fr", rows="5rem 1fr")
    return DOM.div(grid; style=Styles("width" => "400px", "height" => "300px", "margin" => "20px"))
end
```

Now, if we want to do something with lots of rows/columns, e.g. a calendar, it may get tiring to write those out, which is why css offers the `repeat` function:

```@example 1
App() do
    cards = [centered(i) for i in 1:31]
    grid = Grid(cards...; columns="repeat(7, 1fr)")
    return DOM.div(grid; style=Styles("width" => "400px", "margin" => "5px"))
end
```

## Assigning children

Children can be assigned slots in the layout explicitely, and it's also possible to assign them to multiple slots.
The css syntax for this is:

```julia
start_column = 1
end_column = 3
start_row = 1
end_row = 3

style = Styles(
    "grid-column" => "$start_column / $end_column",
    "grid-row" => "$start_row / $end_row"
)
child = DOM.div(style=style) # assign child from slot 1-2
```

To illustrate how this works, here is an interactive app where you can select the slots in the grid, and see the corresponding grid/column assignments:

```@example 1

function centered2d(i, j;)
    return centered("($i, $j)"; dataCol="$i,$j", style=Styles("user-select" => :none))
end

App() do
    cards = [centered2d(i, j) for i in 1:4 for j in 1:4]

    hover_style = Styles(
        "background-color" => :blue,
        "opacity" => 0.2,
        "z-index" => 1,
        "display" => :none,
        "user-select" => :none,
    )

    hover = DOM.div(; style=hover_style)

    grid_style = Styles("position" => :absolute, "top" => 0, "left" => 0)
    size = "300px"
    background_grid = Grid(cards...; columns="repeat(4, 1fr)", gap="0px",
        style=grid_style, height=size, width=size)

    rows = [DOM.div() for i in 1:15]

    selected_grid = Grid(hover, rows...; columns="repeat(4, 1fr)", gap="0px",
        style=grid_style, height=size, width=size)

    style_display = centered("Styles(...)"; width="100%")

    hover_js = js"""
        const hover = $(hover);
        const grid = $(selected_grid);
        const style_display = $(style_display);
        const h2_node = style_display.children[0].children[0];

        let is_dragging = false;
        let start_position = null;
        function get_element(e) {
            const elements = document.elementsFromPoint(e.clientX, e.clientY);
            for (let i = 0; i < elements.length; i++) {
                const element = elements[i];
                if (element.getAttribute('data-col')) {
                    return element;
                }
            }
            return
        }

        function handle_click(current) {
            // Check if the current element is a child of the container
            const index = current.getAttribute('data-col')
            if (index) {
                const start = start_position.split(",").map(x=> parseInt(x))
                const end = index.split(",").map(x=> parseInt(x))

                const [start_row, end_row] = [start[0], end[0]].sort()
                const [start_col, end_col] = [start[1], end[1]].sort()
                const row = (start_row) + " / " + (end_row + 1)
                const col = (start_col) + " / " + (end_col + 1)
                hover.style["grid-row"] = row
                hover.style["grid-column"] = col
                const nelems = 16 - ((end_row - start_row+ 1) * (end_col - start_col+ 1))
                for (let i = 0; i < grid.children.length; i++) {
                    console.log(i)
                    const child = grid.children[i];
                    if (child == hover) {
                        continue
                    }
                    child.style.display = nelems >= i ? "block" : "none";
                }

                h2_node.innerText = 'Styles(\n\"grid-row\" => \"' + row + '\",\n \"grid-column\" => \"' + col + '\"\n)';
            }
        }

        grid.addEventListener('mousedown', (e) => {
            if (!hover) {
                return
            }
            is_dragging = true;
            const current = get_element(e);
            const index = current.getAttribute('data-col')
            if (!index) {
                return;
            }
            start_position = index
            hover.style.display = "block"; // unhide hover element
            handle_click(current);
        });

        grid.addEventListener('mousemove', (e) => {
            if (!is_dragging) return;
            const current = get_element(e);
            handle_click(current);
        });

        document.addEventListener('mouseup', () => {
            is_dragging = false;
        });

    """
    grids = DOM.div(background_grid, selected_grid, hover_js; style=Styles("position" => :relative, "height" => size))

    return Grid(style_display, grids; columns="1fr 2fr", width="100%")
end
```


## Grid areas

We can now easily create complex layouts like this:

```@example 1
App() do

    sidebar = DemoCard(
        "SIDEBAR",
        style = Styles(
            "grid-column" =>  "1",
            "grid-row" =>  "1 / 3",
        )
    )

    header = DemoCard(
        "HEADER",
        style = Styles(
            "grid-column" =>  "2",
            "grid-row" =>  "1",
        )
    )

    main = DemoCard(
        "MAIN",
        style = Styles(
            "grid-column" =>  "2",
            "grid-row" =>  "2",
        )
    )

    grid = Grid(
        sidebar, header, main,
        columns = "2fr 5fr",
        rows = "50px 1fr"
    )
    return DOM.div(grid; style=Styles("height" => "600px", "margin" => "20px", "position" => :relative))
end
```

With `areas`, in css `grid-template-areas` this can be made even simpler:

```@example 1
App() do

    sidebar = DemoCard(
        "SIDEBAR",
        style = Styles("grid-area" =>  "sidebar")
    )

    header = DemoCard(
        "HEADER",
        style = Styles("grid-area" =>  "header")
    )

    main = DemoCard(
        "MAIN",
        style = Styles("grid-area" =>  "main")
    )

    grid = Grid(
        sidebar, header, main,
        columns = "2fr 5fr",
        rows = "50px 1fr",
        areas = """
            'sidebar header'
            'sidebar main';
        """
    )
    return DOM.div(grid; style=Styles("height" => "600px", "margin" => "20px", "position" => :relative))
end
```
The syntax is quite similar to julias matrix syntax, just wrapping all rows into `'...row...'`!
To span multiple rows or columns, the name can be repeated multiple times.


## Alignment


```@example 1
App() do
    grid = Grid(
        DemoCard(), DemoCard(),
        columns = "90px 90px",
    )
    return DOM.div(grid; style=Styles("height" => "200px", "margin" => "20px", "position" => :relative, "background-color" => "#F88379", "padding" => "5px"))
end
```


```@example 1
App() do session
    justification = JSServe.Dropdown(["space-evenly", "center", "end", "space-between", "space-around", "space-evenly"], style=Styles("width" => "200px"))

    grid = Grid(
        DemoCard(), DemoCard(),
        columns = "90px 90px"
    )
    onjs(session, justification.option_index, js""" (idx) => {
        grid = $(grid)
        grid.style["justify-content"] = $(justification.options[])[idx-1]
    }""")
    area_style = Styles("height" => "200px", "width" => "600px", "margin" => "20px", "position" => :relative, "background-color" => "#F88379", "padding" => "5px")
    grid_area = DOM.div(grid; style=area_style)
    return Grid(justification, grid_area; justify_items="center")
end
```

```@example 1
App() do session
    content = JSServe.Dropdown(["space-evenly", "center", "end", "space-between", "space-around"])
    items = JSServe.Dropdown(["stretch", "start", "center", "end"])
    grid = Grid(
        DemoCard(), DemoCard(),
        DemoCard(), DemoCard(),
        columns = "90px 90px"
    )
    onjs(session, content.option_index, js""" (idx) => {
        grid = $(grid)
        const val = $(content.options[])[idx-1]
        grid.style["justify-content"] = val
    }""")
    onjs(session, items.option_index, js""" (idx) => {
        grid = $(grid)
        const val = $(items.options[])[idx-1]
        grid.style["justify-items"] = val
    }""")
    grid_area = DOM.div(grid; style=Styles("height" => "200px", "width" => "600px", "margin" => "20px", "position" => :relative, "background-color" => "#F88379", "padding" => "5px",
        "grid-column" => "1 / 3", "grid-row" => "2"))
    return Grid(content, items, grid_area; width="500px", justify_items="space-around")
end
```


```@example 1
App() do session
    content = JSServe.Dropdown(["space-evenly", "center", "end", "space-between", "space-around"])
    items = JSServe.Dropdown(["stretch", "start", "center", "end"])
    align_content = JSServe.Dropdown(["space-evenly", "center", "end", "space-between", "space-around"])
    align_items = JSServe.Dropdown(["stretch", "start", "center", "end"])
    grid_style = Styles("position" => :absolute, "top" => 0, "left" => 0)
    grid = Grid(
        centered("One"), centered("Two"),
        centered("Three"), centered("Four"),
        columns = "100px 100px",
        rows = "100px 100px",
        style=grid_style
    )

    grid_col() = DOM.div(style=Styles("border" => "2px dashed white", "width"=>"100px"))
    grid_row() = DOM.div(style=Styles("border" => "2px dashed white", "height"=>"100px"))

    shadow_cols = Grid(
        grid_col(), grid_col(),
        columns = "100px 100px",
        style=grid_style
    )
    shadow_rows = Grid(
        grid_row(), grid_row(),
        rows = "100px 100px",
        style=grid_style
    )

    onjs(session, content.option_index, js""" (idx) => {
        const grids = [$(grid), $(shadow_cols)]
        const val = $(content.options[])[idx-1]
        grids.forEach(x=> x.style["justify-content"] = val)
    }""")

    onjs(session, items.option_index, js""" (idx) => {
        const grids = [$(grid), $(shadow_cols)]
        const val = $(items.options[])[idx-1]
        grids.forEach(x=> x.style["justify-items"] = val)
    }""")

    onjs(session, align_content.option_index, js""" (idx) => {
        const grids = [$(grid), $(shadow_rows)]
        const val = $(align_content.options[])[idx-1]
        grids.forEach(x=> x.style["align-content"] = val)
    }""")

    onjs(session, align_items.option_index, js""" (idx) => {
        const grids = [$(grid), $(shadow_rows)]
        const val = $(align_items.options[])[idx-1]
        grids.forEach(x=> x.style["align-items"] = val)
    }""")

    grid_area = DOM.div(grid, shadow_cols, shadow_rows; style=Styles(
        "height" => "400px", "width" => "400px",
        "margin" => "20px",
        "padding" => "5px",
        "position" => :relative,
        "background-color" => "#F88379",
        "grid-column" => "1 / 3", "grid-row" => "4"))

    text(t) = DOM.div(t; style=Styles("font-size" => "1.3rem", "font-weight" => "bold"))
    final_grid = Grid(
        text("Row Alignment"), text("Col Justification"),
        align_content, content,
        align_items, items,
        grid_area;
        rows = "2rem 1rem 2rem 1fr",
        align_items = "center",
        justify_items="begin", justify_content="center",
        width="400px")

    return DOM.div(final_grid, style=Styles("padding" => "20px"))
end
```
