
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

    # CSS for hover effects + offline banner. Banner uses a dedicated
    # `.bonito-offline-banner` class so apps can re-style it via Bonito.Styles
    # without overriding the LED. Hidden by default; the JS toggles
    # `display:flex` when the JS-side websocket give-up fires.
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
        CSS(
            ".bonito-offline-banner",
            "display"          => "none",
            "position"         => "fixed",
            "top"              => "0",
            "left"             => "0",
            "right"            => "0",
            "z-index"          => "10000",
            "padding"          => "12px 20px",
            "background"       => indicator.disconnected_color,
            "color"            => "white",
            "font-family"      => "system-ui, -apple-system, sans-serif",
            "font-size"        => "14px",
            "font-weight"      => "500",
            "box-shadow"       => "0 2px 8px rgba(0,0,0,0.2)",
            "align-items"      => "center",
            "justify-content"  => "center",
            "gap"              => "16px",
        ),
        CSS(
            ".bonito-offline-banner.bonito-offline-active",
            "display" => "flex",
        ),
        CSS(
            ".bonito-offline-banner button",
            "padding"          => "6px 16px",
            "background"       => "white",
            "color"            => indicator.disconnected_color,
            "border"           => "none",
            "border-radius"    => "4px",
            "font-weight"      => "600",
            "cursor"           => "pointer",
            "font-size"        => "13px",
        ),
        CSS(
            ".bonito-offline-banner button:hover",
            "filter" => "brightness(0.95)",
        ),
    )

    final_style = Styles(default_style, indicator.style)

    # LED + offline banner. The banner is always rendered (display:none)
    # so the JS can flip a class instead of injecting nodes mid-failure.
    led_element = DOM.div(;
        style=final_style,
        title="Disconnected",
        class="bonito-indicator",
    )

    banner_element = if indicator.offline_banner
        DOM.div(
            DOM.span(indicator.offline_message),
            DOM.button(indicator.offline_button_label;
                       onclick="window.location.reload()"),
            class="bonito-offline-banner",
        )
    else
        nothing
    end

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

        // The banner toggles via classList; we look it up lazily so it works
        // even if the indicator is registered before the banner is mounted.
        function getBanner() {
            return document.querySelector('.bonito-offline-banner');
        }

        const indicatorObj = {
            onStatusChange: function(status) {
                if (!led) return;
                const color = colors[status] || colors.disconnected;
                led.style.backgroundColor = color;
                led.style.boxShadow = '0 0 ' + ($(indicator.size) / 2) + 'px ' + color;
                led.title = tooltips[status] || tooltips.disconnected;

                // Show the banner only on the give-up state ("disconnected").
                // "connecting" is the transient retry phase — banner stays
                // hidden so a 2s blip doesn't flash a scary modal at the user.
                const banner = getBanner();
                if (banner) {
                    if (status === "disconnected") {
                        banner.classList.add('bonito-offline-active');
                    } else {
                        banner.classList.remove('bonito-offline-active');
                    }
                }
            }
        };

        if (typeof Bonito !== 'undefined' && Bonito.register_connection_indicator) {
            Bonito.register_connection_indicator(indicatorObj);
        }
    }
    """

    onload(session, led_element, indicator_script)

    # Reactive render of the server-side error slot. `record_session_error!`
    # writes the live `Exception` into `indicator.error[]`; `map` derives a
    # Hyperscript Node that Bonito's normal Observable-of-Node rendering
    # swaps into the page when the value changes. Apps that want a richer
    # error UI can construct their own `ConnectionIndicator` and overload
    # `render_error`.
    # B21: session-scope so the listener is deregistered by `free(session)`
    # instead of leaking one per render of the indicator.
    error_dom = map(render_error, session, indicator.error)

    children = banner_element === nothing ?
        (indicator_css, led_element, error_dom) :
        (indicator_css, led_element, banner_element, error_dom)
    return jsrender(session, DOM.div(children...))
end

# Allow jsrender to handle nothing (no indicator)
jsrender(session::Session, ::Nothing) = nothing

"""
    render_error(err) -> Node

Render a server-side error for display inside a `ConnectionIndicator`. Default
shows nothing for `nothing` and a banner with the error type + message for an
`Exception`. Override for richer per-app rendering by defining a method on
your own indicator type or wrapping a `ConnectionIndicator` and supplying a
different mapping function.
"""
render_error(::Nothing) = DOM.div(; style="display:none")
function render_error(err::Exception)
    return DOM.div(
        DOM.div("Server error: ", string(typeof(err));
                style="font-weight:600; margin-bottom:4px;"),
        DOM.pre(sprint(showerror, err);
                style="white-space:pre-wrap; margin:0; font-family:ui-monospace, monospace; font-size:13px;");
        class="bonito-server-error",
        style=string(
            "position:fixed; top:48px; left:0; right:0; z-index:10001; ",
            "padding:12px 20px; background:#7f1d1d; color:white; ",
            "font-family:system-ui, -apple-system, sans-serif; font-size:14px; ",
            "box-shadow:0 2px 8px rgba(0,0,0,0.2);",
        ),
    )
end
