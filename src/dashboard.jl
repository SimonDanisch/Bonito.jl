function Card(content;
              style::CSS=CSS(),
              backgroundcolor=RGBA(1, 1, 1, 0.2),
              shadow_size="0 4px 8px",
              padding="6px",
              margin="2px",
              shadow_color=RGBA(0, 0, 0.2, 0.2),
              width="auto",
              height="auto",
              border_radius = "10px",
              attributes...)
    color = convert_css_attribute(shadow_color)
    css = CSS(style,
        "width" => width,
        "height" => height,
        "padding" => padding,
        "margin" => margin,
        "background-color" => backgroundcolor,
        "border-radius" => border_radius,
        "box-shadow" => "$(shadow_size) $(color)"
    )
    return DOM.div(content; style=css, attributes...)
end

function Grid(elems...;
        style::CSS=CSS(),
        columns = "none",
        rows="none",
        gap="10px",
        areas="none",
        justify_content="normal",
        justify_items="legacy",
        align_content="normal",
        align_items="legacy",
        width="100%",
        height="100%",
        kwargs...)

    css = CSS(style,
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

function Row(args...; class="", attributes...)
    return DOM.div(args...;
                   attributes...,
                   class="mx-2 flex flex-row $class")
end

function Col(args...; class="", attributes...)
    return DOM.div(args...;
                   attributes...,
                   class="my-2 flex flex-col $class",)
end
