# App

The `App` type is the main entry point for creating Bonito applications. It wraps your content and handles the connection between Julia and the browser.

## Basic Usage

```julia
using Bonito

# Simple app with static content
app = App(DOM.div("Hello World"))

# App with session access
app = App() do session::Session
    button = Button("Click me")
    on(button.value) do _
        println("Button clicked!")
    end
    return button
end

# App with request access (useful for routing)
app = App() do session::Session, request::HTTP.Request
    path = request.target
    return DOM.div("You requested: $path")
end
```

## App Options

The `App` constructor accepts the following keyword arguments:

```julia
App(handler;
    title="Bonito App",              # Browser tab title
    indicator=ConnectionIndicator()  # Connection status indicator (or nothing to disable)
)
```

## Connection Indicator

By default, every App displays a small LED-like indicator in the top-right corner showing the connection status to the Julia server:

- **Green**: Connected to the server
- **Yellow**: Connecting or reconnecting
- **Red**: Disconnected from the server
- **Gray**: No connection mode (static export)

The indicator also blinks during large data transfers.

### Disabling the Indicator

```julia
App(; indicator=nothing) do
    DOM.h1("No indicator on this app")
end
```

### Customizing Colors and Size

```julia
App(; indicator=ConnectionIndicator(
    connected_color="lime",
    connecting_color="orange",
    disconnected_color="red",
    no_connection_color="gray",
    size=15  # pixels
)) do
    DOM.h1("Custom indicator colors")
end
```

!!! note "Browser Display"
    When using browser display (e.g., displaying apps in VS Code or via `Server`), the indicator is rendered on the root session which persists across app updates. Changes to the `indicator` argument will not take effect until you refresh the browser page to create a new root session.

### Customizing Position

By default, the indicator is positioned in the top-right corner. You can change this:

```julia
# Bottom-left corner
App(; indicator=ConnectionIndicator(
    top="auto",
    right="auto",
    style=Styles(
        "bottom" => "10px",
        "left" => "10px"
    )
)) do
    DOM.h1("Indicator in bottom-left")
end

# Center-top with custom styling
App(; indicator=ConnectionIndicator(
    right="auto",
    style=Styles(
        "left" => "50%",
        "transform" => "translateX(-50%)",
        "border" => "2px solid white"
    )
)) do
    DOM.h1("Centered indicator")
end
```

### ConnectionIndicator Arguments

| Argument | Default | Description |
|----------|---------|-------------|
| `connected_color` | `"#22c55e"` | Color when connected (green) |
| `connecting_color` | `"#eab308"` | Color when connecting (yellow) |
| `disconnected_color` | `"#ef4444"` | Color when disconnected (red) |
| `no_connection_color` | `"#6b7280"` | Color for NoConnection mode (gray) |
| `size` | `10` | Diameter in pixels |
| `position` | `"fixed"` | CSS position property |
| `top` | `"10px"` | Distance from top |
| `right` | `"10px"` | Distance from right |
| `style` | `Styles()` | Additional CSS styles |

## Creating a Custom Indicator

For complete control over the indicator's appearance and behavior, you can create your own by subtyping `AbstractConnectionIndicator`:

```julia
using Bonito

struct TextIndicator <: AbstractConnectionIndicator
    font_size::Int
end

TextIndicator(; font_size=12) = TextIndicator(font_size)

function Bonito.jsrender(session::Session, indicator::TextIndicator)
    # Create the DOM element
    status_text = DOM.span("Connecting...";
        style=Styles(
            "position" => "fixed",
            "top" => "10px",
            "right" => "10px",
            "font-size" => "$(indicator.font_size)px",
            "font-family" => "monospace",
            "padding" => "4px 8px",
            "background" => "rgba(0,0,0,0.7)",
            "color" => "white",
            "border-radius" => "4px",
            "z-index" => "9999"
        )
    )

    # JavaScript to handle status changes
    init_script = js"""
    function initTextIndicator(element) {
        const messages = {
            connected: "✓ Connected",
            connecting: "◐ Connecting...",
            disconnected: "✗ Disconnected",
            no_connection: "○ Static Mode"
        };

        const colors = {
            connected: "#22c55e",
            connecting: "#eab308",
            disconnected: "#ef4444",
            no_connection: "#6b7280"
        };

        const indicator = {
            onStatusChange: function(status, connectionType) {
                element.textContent = messages[status] || messages.disconnected;
                element.style.color = colors[status] || colors.disconnected;
            },
            onDataTransfer: function(isTransferring) {
                element.style.opacity = isTransferring ? "0.6" : "1";
            }
        };

        Bonito.register_connection_indicator(indicator);
    }
    """

    Bonito.onload(session, status_text, init_script)
    return Bonito.jsrender(session, status_text)
end

# Use it
App(; indicator=TextIndicator(font_size=14)) do
    DOM.h1("App with text-based indicator")
end
```

### JavaScript API for Custom Indicators

When creating a custom indicator, register it with Bonito using these JavaScript functions:

```javascript
// Register your indicator object
Bonito.register_connection_indicator({
    // Called when connection status changes
    onStatusChange: function(status, connectionType) {
        // status: "connected" | "connecting" | "disconnected" | "no_connection"
        // connectionType: "websocket" | "no_connection" | etc.
    },

    // Optional: Called during large data transfers
    onDataTransfer: function(isTransferring) {
        // isTransferring: true when transfer starts, false when it ends
    }
});

// Unregister the current indicator
Bonito.unregister_connection_indicator();

// Status constants (for comparison)
Bonito.ConnectionStatus.CONNECTED      // "connected"
Bonito.ConnectionStatus.CONNECTING     // "connecting"
Bonito.ConnectionStatus.DISCONNECTED   // "disconnected"
Bonito.ConnectionStatus.NO_CONNECTION  // "no_connection"
```

## Connection Types

Bonito supports different connection types for different deployment scenarios:

| Connection Type | Description | Indicator Behavior |
|----------------|-------------|-------------------|
| `WebSocketConnection` | Default, real-time bidirectional | Shows connected/disconnected |
| `NoConnection` | Static export, no Julia interaction | Shows gray "no connection" |

The indicator automatically adapts to the connection type being used.
