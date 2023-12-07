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
    attributes...,
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
    return DOM.div(content; style=css, attributes...)
end

function Grid(
    elems...;
    style::Styles=Styles(),
    columns="none",
    rows="none",
    gap="10px",
    areas="none",
    justify_content="normal",
    justify_items="legacy",
    align_content="normal",
    align_items="legacy",
    width="100%",
    height="100%",
    kwargs...,
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
    return DOM.div(elems...; style=css, kwargs...)
end

function Row(args...; attributes...)
    return Grid(args...; rows="1fr", columns="repeat($(length(args)), 1fr)", attributes...)
end

function Col(args...; attributes...)
    return Grid(args...; columns="1fr", attributes...)
end

struct StylableSlider{T} <: AbstractSlider{T}
    values::Observable{Vector{T}}
    value::Observable{T}
    style::Styles
    track_style::Styles
    thumb_style::Styles
    track_active_style::Styles
end

function StylableSlider(
    range::AbstractVector{T};
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
) where {T}

    half_thumb_width = thumb_width / 2

    style = Styles(
        style,
        "display" => "grid",
        "grid-template-columns" => "1fr",
        "grid-template-rows" => "$(slider_height)px",
        "align-items" => "center",
        "margin" => "5px",
        "position" => "relative",
        "padding-right" => "$(half_thumb_width)px",
        "padding-left" => "$(half_thumb_width)px",
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

    slider = StylableSlider(
        Observable{Vector{T}}(range),
        Observable(value),
        style,
        track_style,
        thumb_style,
        track_active_style,
    )
    slider[] = value
    return slider
end
function Label(value; style=Styles(), attributes...)
    styled = Styles(style, "font-size" => "1rem", "font-weight" => 600)
    return DOM.span(value; style=styled)
end

function Labeled(object, value; value_style=Styles(), attributes...)
    return Grid(
        object,
        Label(value; style=value_style);
        rows="1fr",
        columns="1fr min-content",
        align_items="center",
        justify_items="stretch",
        width="100%",
        attributes...
    )
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
        function set_thumb(e) {
            const values = $(slider.values).value;
            const nsteps = values.length;
            const thumb_width = thumb.offsetWidth / 2;
            const width = track.offsetWidth;
            const step_width = width / nsteps;
            let new_left = e.clientX - container.getBoundingClientRect().left;
            new_left = Math.max(new_left, 0);
            new_left = Math.min(new_left, width);
            new_left = Math.round(new_left / step_width) * step_width;
            thumb.style.left = (new_left - thumb_width) + 'px';  // Update the left position of the thumb
            track_active.style.width = new_left + 'px';  // Update the active track
            const index = Math.round((new_left / width) * (nsteps - 1));
            $(slider.value).notify(values[index]);
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

function Base.setindex!(slider::StylableSlider, value)
    # should be only numbers right now, which should also be sorted
    # This may change once we allow `Slider(array)` in WidgetsBase
    values = slider.values
    idx = findfirst(x -> x >= value, values[])

    if isnothing(idx)
        @warn(
            "Value $(value) out of range for the values of slider (highest value: $(last(values[]))). Setting to highest value!"
        )
        idx = length(values[])
    end
    slider.value[] = values[][idx]
    return idx
end
