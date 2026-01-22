
function jsrender(session::Session, indicator::ConnectionIndicator)
    # Build the default styles for the indicator LED
    default_style = Styles(
        "width" => "$(indicator.size)px",
        "height" => "$(indicator.size)px",
        "border-radius" => "50%",
        "position" => indicator.position,
        "top" => indicator.top,
        "right" => indicator.right,
        "background-color" => indicator.disconnected_color,
        "box-shadow" => "0 0 $(indicator.size ÷ 2)px $(indicator.disconnected_color)",
        "transition" => "background-color 0.3s ease, box-shadow 0.3s ease, transform 0.15s ease",
        "cursor" => "pointer",
        "z-index" => "9999",
        "user-select" => "none",
        "pointer-events" => "auto",
    )

    # CSS for hover effects
    indicator_css = Styles(
        CSS(
            ".bonito-indicator:hover",
            "transform" => "scale(1.3)",
            "filter" => "brightness(1.2)",
        ),
        CSS(
            ".bonito-indicator:active",
            "transform" => "scale(1.1)",
        ),
    )

    final_style = Styles(default_style, indicator.style)

    # Create the LED element
    led_element = DOM.div(;
        style=final_style,
        title="Disconnected",
        class="bonito-indicator",
    )

    # JavaScript to register the indicator and handle state changes
    # Use onload to ensure the LED element exists in the DOM
    indicator_script = js"""
    function initIndicator(led) {
        const colors = {
            connected: $(indicator.connected_color),
            connecting: $(indicator.connecting_color),
            disconnected: $(indicator.disconnected_color),
            no_connection: $(indicator.no_connection_color)
        };

        const tooltips = {
            connected: "Connected to Julia server",
            connecting: "Connecting to Julia server...",
            disconnected: "Disconnected from Julia server",
            no_connection: "No connection (static mode) - Julia interaction disabled"
        };

        const indicatorObj = {
            onStatusChange: function(status) {
                if (!led) return;
                // Map status to color
                const color = colors[status] || colors.disconnected;
                led.style.backgroundColor = color;
                led.style.boxShadow = '0 0 ' + ($(indicator.size) / 2) + 'px ' + color;

                // Update tooltip
                led.title = tooltips[status] || tooltips.disconnected;
            }
        };

        // Register with Bonito
        if (typeof Bonito !== 'undefined' && Bonito.register_connection_indicator) {
            Bonito.register_connection_indicator(indicatorObj);
        }
    }
    """

    # Use onload to ensure the element is in the DOM before registering
    onload(session, led_element, indicator_script)

    return jsrender(session, DOM.div(indicator_css, led_element))
end

# Allow jsrender to handle nothing (no indicator)
jsrender(session::Session, ::Nothing) = nothing
