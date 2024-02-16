CARD_EXAMPLE = """
    App() do
        Card(
            DOM.h1("This is a card");
            width="200px",
            height="200px",
            backgroundcolor="white",
            shadow_size="0 0 10px",
            shadow_color="blue",
            padding="20px",
            margin="20px",
            border_radius="20px",
            style = Styles(
                CSS("hover", "background-color" => "lightgray")
            )
        )
    end
"""

"""
    Card(
        content;
        style::Styles=Styles(),
        backgroundcolor=RGBA(1, 1, 1, 0.2),
        shadow_size="0 4px 8px",
        padding="12px",
        margin="2px",
        shadow_color=RGBA(0, 0, 0.2, 0.2),
        width="auto",
        height="auto",
        border_radius="10px",
        div_attributes...,
    )

A Card is a container with a shadow and rounded corners.
It is a good way to group elements together and make them stand out from the background.
One can easily style them via the above keyword arguments or via the `style` argument with any CSS attribute.

# Example

```@example
$(CARD_EXAMPLE)
```
"""
function Card(
    content;
    style::Styles=Styles(),
    backgroundcolor=RGBA(1, 1, 1, 0.2),
    shadow_size="0 4px 8px",
    padding="12px",
    margin="2px",
    shadow_color=RGBA(0, 0, 0.2, 0.2),
    width="auto",
    height="auto",
    border_radius="10px",
    div_attributes...,
)
    color = convert_css_attribute(shadow_color)
    css = Styles(
        style,
        "width" => width,
        "height" => height,
        "padding" => padding,
        "margin" => margin,
        "background-color" => backgroundcolor,
        "border-radius" => border_radius,
        "box-shadow" => "$(shadow_size) $(color)",
    )
    return DOM.div(content; style=css, div_attributes...)
end

"""
    Grid(
        elems...;
        gap="10px",
        width="100%",
        height="100%",
        # All below Attributes are set to the default CSS values:
        columns="none",
        rows="none",
        areas="none",
        justify_content="normal",
        justify_items="legacy",
        align_content="normal",
        align_items="legacy",
        style::Styles=Styles(),
        div_attributes...,
    )

A Grid is a container that lays out its children in a grid, based on the powerful css `display: grid` property.
"""
function Grid(
    elems...;
    gap="10px",
    width="100%",
    height="100%",
    # All below Attributes are set to the default CSS values:
    columns="none",
    rows="none",
    areas="none",
    justify_content="normal",
    justify_items="legacy",
    align_content="normal",
    align_items="legacy",
    style::Styles=Styles(),
    div_attributes...,
)
    css = Styles(
        style,
        "display" => "grid",
        "grid-template-columns" => columns,
        "grid-template-rows" => rows,
        "grid-gap" => gap,
        "grid-template-areas" => areas,
        "justify-content" => justify_content,
        "justify-items" => justify_items,
        "align-content" => align_content,
        "align-items" => align_items,
        "width" => width,
        "height" => height,
    )
    return DOM.div(elems...; style=css, div_attributes...)
end

"""
    Row(elems...; grid_attributes...)

Places objects in a row, based on `Grid`.
"""
function Row(args...; grid_attributes...)
    return Grid(
        args...; rows="1fr", columns="repeat($(length(args)), 1fr)", grid_attributes...
    )
end

"""
    Col(elems...; grid_attributes...)

Places objects in a column, based on `Grid`.
"""
function Col(args...; grid_attributes...)
    return Grid(args...; columns="1fr", grid_attributes...)
end

"""
    Centered(content; style=Styles(), grid_attributes...)

Creates an element where the content is centered via `Grid`.
"""
function Centered(content; style=Styles(), grid_attributes...)
    return Grid(
        content;
        justify_content=:center,
        justify_items=:center,
        align_content=:center,
        align_items=:center,
        columns="1fr",
        style=Styles(style),
        grid_attributes...,
    )
end

struct StylableSlider{T} <: AbstractSlider{T}
    values::Observable{Vector{T}}
    value::Observable{T}
    index::Observable{Int}
    style::Styles
    track_style::Styles
    thumb_style::Styles
    track_active_style::Styles
end


const STYLABLE_SLIDER_EXAMPLE = """
App() do
    Bonito.StylableSlider(
        1:10;
        value=5,
        slider_height=20,
        track_color="lightblue",
        track_active_color="#F0F8FF",
        thumb_color="#fff",
        style=Styles(
            CSS("hover", "background-color" => "lightgray"),
            CSS("border-radius" => "0px"),
        ),
        track_style=Styles(
            "border-radius" => "3px",
            "border" => "1px solid black",
        ),
        thumb_style=Styles(
            "border-radius" => "3px",
            "border" => "1px solid black",
        ),
    )
end
"""

"""
    StylableSlider(
        range::AbstractVector;
        value=first(range),
        slider_height=15,
        thumb_width=slider_height,
        thumb_height=slider_height,
        track_height=slider_height / 2,
        track_active_height=track_height + 2,
        backgroundcolor="transparent",
        track_color="#eee",
        track_active_color="#ddd",
        thumb_color="#fff",
        style::Styles=Styles(),
        track_style::Styles=Styles(),
        thumb_style::Styles=Styles(),
        track_active_style::Styles=Styles(),
    )

Creates a Stylable Slider, where the basic attributes are easily custimizable via keyword arguments,
while the more advanced details can be styled via the `style`, `track_style`, `thumb_style` and `track_active_style` arguments with the whole might of CSS.
This does not use `<input type="range">` but is a custom implementation using `<div>`s javascript,
since it is not easily possible to style the native slider in a cross-browser way.
For using pure HTML sliders, use `Bonito.Slider`.

# Example

```@example
$(STYLABLE_SLIDER_EXAMPLE)
```
"""
function StylableSlider(
    range::AbstractVector{T};
    index=1,
    slider_height=15,
    thumb_width=slider_height,
    thumb_height=slider_height,
    track_height=slider_height / 2,
    track_active_height=track_height + 2,
    backgroundcolor="transparent",
    track_color="#eee",
    track_active_color="#ddd",
    thumb_color="#fff",
    style::Styles=Styles(),
    track_style::Styles=Styles(),
    thumb_style::Styles=Styles(),
    track_active_style::Styles=Styles(),
) where {T}
    half_thumb_width = thumb_width / 2

    style = Styles(
        style,
        "display" => "grid",
        "grid-template-columns" => "1fr",
        "grid-template-rows" => "$(slider_height)px",
        "align-items" => "center",
        "margin" => "$(slider_height ÷ 3)px",
        "position" => "relative",
        "padding-right" => "$(2 + half_thumb_width)px",
        "padding-left" => "$(2 + half_thumb_width)px",
        "background-color" => backgroundcolor,
    )

    track_style = Styles(
        track_style,
        "position" => "absolute",
        "width" => "100%",
        "height" => "$(track_height)px",
        "background-color" => track_color,
        "border-radius" => "3px",
        "border" => "1px solid #ccc",
    )

    track_active_style = Styles(
        track_active_style,
        "position" => "absolute",
        "width" => "0px",
        "height" => "$(track_active_height)px",
        "background-color" => track_active_color,
        "border-radius" => "3px",
        "border" => "1px solid #ccc",
    )

    thumb_style = Styles(
        thumb_style,
        "width" => "$(thumb_width)px",
        "height" => "$(thumb_height)px",
        "background-color" => "white",
        "border-radius" => "50%",
        "cursor" => "pointer",
        "position" => "absolute",
        "border" => "1px solid #ccc",
        "left" => "$(-half_thumb_width)px",
        "background-color" => thumb_color,
    )
    values = Observable{Vector{T}}(range; ignore_equal_values=true)
    index_obs = Observable(index; ignore_equal_values=true)
    value_obs = map(getindex, values, index_obs; ignore_equal_values=true)
    slider = StylableSlider(
        values,
        value_obs,
        index_obs,
        style,
        track_style,
        thumb_style,
        track_active_style,
    )
    return slider
end

function jsrender(session::Session, slider::StylableSlider)
    # Define the CSS styles
    container_style = slider.style

    track_style = slider.track_style

    track_active_style = slider.track_active_style

    thumb_style = slider.thumb_style

    # Create elements
    thumb = DOM.div(; style=thumb_style)
    track = DOM.div(; style=track_style)
    track_active = DOM.div(; style=track_active_style)
    container = DOM.div(track, track_active, thumb; style=container_style)

    # JavaScript for interactivity
    jscode = js"""
    (container)=> {
        const thumb = $(thumb);
        const track_active = $(track_active);
        const track = $(track);
        let isDragging = false;
        const nsteps_obs = $(map(length, slider.values))
        let last_index = $(slider.index).value;
        function set_thumb_index(index) {
            if (index === last_index) {
                return
            }
            last_index = index;
            const thumb_width = thumb.offsetWidth / 2;
            const nsteps = nsteps_obs.value;
            const step_width = track.offsetWidth / (nsteps-1);
            const new_left = (index - 1) * step_width;
            thumb.style.left = (new_left - thumb_width) + 'px';  // Update the left position of the thumb
            track_active.style.width = new_left + 'px';  // Update the active track
        }
        $(slider.index).on(idx=> set_thumb_index(idx));
        function set_thumb(e) {
            const nsteps = nsteps_obs.value;
            const thumb_width = thumb.offsetWidth / 2;
            const width = track.offsetWidth;
            const step_width = width / (nsteps - 1);
            let new_left = e.clientX - container.getBoundingClientRect().left;
            new_left = Math.max(new_left, 0);
            new_left = Math.min(new_left, width);
            new_left = Math.round(new_left / step_width) * step_width;
            thumb.style.left = (new_left - thumb_width) + 'px';  // Update the left position of the thumb
            track_active.style.width = new_left + 'px';  // Update the active track
            const index = Math.round((new_left / width) * (nsteps - 1));
            last_index = index;
            if (index !== $(slider.index).value) {
                $(slider.index).notify(index + 1);
            }
        }
        const controller = new AbortController();
        document.addEventListener('mousedown', function (e) {
            if(e.target === thumb || e.target === track_active || e.target === track || e.targar === container){
                isDragging = true;
                set_thumb(e);
                e.preventDefault();  // Prevent default behavior
            }
        }, { signal: controller.signal});
        document.addEventListener('mouseup', function () {
            if (!document.body.contains(container)) {
                controller.abort();
            }
            isDragging = false;
        }, { signal: controller.signal });
        document.addEventListener('mousemove', function (e) {
            if (isDragging) {
                set_thumb(e);
            }
        }, { signal: controller.signal });
    }
    """
    onload(session, container, jscode)
    return jsrender(session, container)
end


"""
    Label(value; style=Styles(), attributes...)

A Label is a simple text element, with a bold font and a font size of 1rem.
"""
function Label(value; style=Styles(), attributes...)
    styled = Styles(style, "font-size" => "1rem", "font-weight" => 600)
    return DOM.span(value; style=styled)
end


const LABELED_EXAMPLE = """
App() do
    label_style = Styles(
        "color" => "white",
        "padding" => "3px",
        "font-size" => "1.5rem",
        "text-shadow" => "0px 0px 10px black, 1px 1px 3px black")
    slider = StylableSlider(1:10)
    Card(Labeled(slider, slider.value; label_style=label_style, width="auto"); backgroundcolor="gray")
end
"""

"""
    Labeled(object, label; label_style=Styles(), attributes...)

A Labeled container with a simople layout to put a label next to an object.

```@example
$(LABELED_EXAMPLE)
```
"""
function Labeled(object, label; label_style=Styles(), attributes...)
    return Grid(
        object,
        Label(label; style=label_style);
        rows="1fr",
        columns="1fr min-content",
        align_items="center",
        justify_items="stretch",
        attributes...,
    )
end



function LabelGrid(widget_pairs; label_style=Styles(), grid_kw...)
    elements = []
    for (name, widget) in widget_pairs
        push!(elements, Bonito.Label(name; style=label_style), widget)
    end
    return Grid(
        elements...;
        columns="min-content 1fr",
        justify_content="begin",
        align_items="center",
        grid_kw...,
    )
end
