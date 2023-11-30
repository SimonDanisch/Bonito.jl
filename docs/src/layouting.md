# Layouting

```@setup 1
using JSServe
Page()
```


```@example 1
using JSServe: Card, Grid


function DemoCard(content=DOM.div(); height="auto", width="auto", attributes...)
    return Card(content; height=height, width=width,
        backgroundcolor=:gray, border_radius="2px", attributes...)
end


App() do sess
    s = JSServe.Slider(1:10)
    cards = map(s.value) do n
        cards = [DemoCard(height="50px", width="300px") for i in 1:n]
        return Grid(cards;)
    end
    return JSServe.record_states(sess, Grid(s, cards))
end
```


```@example 1
App() do sess
    s = JSServe.Slider(1:10)
    cards = map(s.value) do n
        cards = [DemoCard(width="300px") for i in 1:n]
        Grid(cards; height="300px")
    end
    return JSServe.record_states(sess, Grid(s, cards))
end
```


```@example 1
App() do
    grid = Grid(DemoCard(), DemoCard();
        height="300px", columns="25% 75%")
    return grid
end
```


```@example 1
App() do sess
    container_width = Slider(5:0.1:100)
    container_width[] = 100
    imstyle = CSS(
        "display" => :block, "position" => :relative, "overflow" => :clip, "overflow-clip-margin" => :content_box, "width" => "100px"
    )
    img = DOM.img(; src="https://docs.makie.org/stable/assets/makie_logo_transparent.svg", style=imstyle)
    style = CSS("position" => :relative, "background-color" => :gray, "display" => :flex, "justify-content" => :center, "align-items" => :center)

    function example_grid(cols)
        grid = Grid(DemoCard(img; style=style), DemoCard(DOM.div(); style=style); columns=cols)
        container = DOM.div(grid; style=CSS("height" => "200px", "width" => "500px"))
        return Grid(container; rows="1fr", justify_content="center"), container
    end
    pgrid, p1 = example_grid("25% 75%")
    frgrid, p2 = example_grid("1fr 3fr")
    grid_percent = DOM.div(Grid(pgrid; rows="1fr"))
    grid_fr = DOM.div(Grid(frgrid; rows="1fr"))

    onjs(sess, container_width.value, js"w=> {$(p1).style.width = (5 * w) + 'px';}")
    onjs(sess, container_width.value, js"w=> {$(p2).style.width = (5 * w) + 'px';}")
    return Grid(container_width, grid_percent, grid_fr; columns="1fr")
end
```

```@example 1
App() do
    style = CSS("background-color" => :gray, "color" => :white, "place_content" => :center, "position" => :relative, "display" => :grid, "height" => "100px")
    cards = [DemoCard(DOM.div(i; style=style)) for i in 1:3]
    grid = Grid(cards...; columns="1fr 3fr")
    return DOM.div(grid; style=CSS("width" => "400px", "height" => "200px", "margin" => "5px"))
end
```


```@example 1
App() do
    style = CSS("color" => :white, "place-content" => :center, "position" => :relative, "display" => :grid, "height" => "100px")
    cards = [DemoCard(DOM.div(i; style=style)) for i in 1:4]
    grid = Grid(cards...; columns="1fr 3fr", rows="5rem 1fr")
    return DOM.div(grid; style=CSS("width" => "400px", "height" => "200px", "margin" => "5px"))
end
```

```@example 1
App() do
    style = CSS("color" => :white, "place-content" => :center, "position" => :relative, "display" => :grid, "height" => "100px")
    cards = [DemoCard(DOM.div(i; style=style)) for i in 1:31]
    grid = Grid(cards...; columns="repeat(7, 1fr)")
    return DOM.div(grid; style=CSS("width" => "400px", "margin" => "5px"))
end
```

```@example 1
App() do
    style = CSS("border-bottom" => "2px dashed", "border-left" => "2px dashed")
    centered_style = CSS("place-content" => :center, "position" => :relative, "display" => :grid, "color" => :white, "height" => "100%", "user-select" => :none)
    function centered(i, j)
        return DOM.div("($i, $j)"; style=centered_style, dataCol="$i,$j")
    end
    cards = [DOM.div(centered(i, j); dataCol="$i,$j", style=CSS(style, "background-color" => "gray"))
             for i in 1:4 for j in 1:4]

    hover_style = CSS(
        "background-color" => :blue,
        "opacity" => 0.2,
        "z-index" => 1,
        "display" => :none,
        "user-select" => :none,
    )

    hover = DOM.div(; style=hover_style)

    grid_style = CSS("position" => :absolute, "top" => 0, "left" => 0)

    background_grid = Grid(cards...; columns="repeat(4, 1fr)", width="100%", height="100%", gap="0px",
        style=grid_style)

    rows = [DOM.div() for i in 1:15]
    selected_grid = Grid(hover, rows...; columns="repeat(4, 1fr)", width="100%", height="100%", gap="0px",
        style=grid_style)

    style_display = DOM.div(""; style=CSS("background-color" => :gray, "color" => :white, "padding" => "10px"))

    hover_js = js"""
        const hover = $(hover);
        const grid = $(selected_grid);
        const style_display = $(style_display);

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
                console.log(grid.children.length)
                for (let i = 0; i < grid.children.length; i++) {
                    console.log(i)
                    const child = grid.children[i];
                    if (child == hover) {
                        continue
                    }
                    child.style.display = nelems >= i ? "block" : "none";
                }
                style_display.innerText = ".selection {\n \t grid-row: " + row + ";\n\tgrid-column: " + col + ";\n}"
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
    grids = DOM.div(background_grid, selected_grid, hover_js; style=CSS("width" => "400px", "height" => "200px", "position" => :relative))
    outer_grid = Grid(grids, style_display; columns="1fr 1fr")
    return DOM.div(outer_grid; style=CSS("width" => "600px", "height" => "200px"))
end
```
