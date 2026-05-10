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
    title="Bonito App",     # Browser tab title
    indicator=nothing,       # Connection status indicator (nothing by default)
    loading_page=nothing     # Loading page shown while handler runs (nothing by default)
)
```

## Loading Page

When an app takes time to initialize (e.g. loading data, compiling code), users see a blank page. The `loading_page` option shows a loading spinner while the handler runs, then replaces it with the real content once ready.

### Basic Usage

```julia
app = App(; loading_page=LoadingPage()) do session
    data = expensive_setup()  # Takes a few seconds
    return DOM.div(data)
end
```

When `loading_page` is set, the app DOM is wrapped in an `Observable`. The loading page is displayed immediately, and the handler runs asynchronously. Once the handler returns, the loading page is replaced with the actual app content via Bonito's reactive subsession mechanism.

### Customization

`LoadingPage` accepts the following keyword arguments:

| Argument | Default | Description |
|----------|---------|-------------|
| `text` | `"Loading Bonito App"` | Text shown below the spinner |
| `spinner` | `RippleSpinner()` | Spinner component to display |
| `style` | `Styles()` | Additional CSS styles for the container |

```julia
# Custom loading message and spinner size
app = App(; loading_page=LoadingPage(
    text="Please wait...",
    spinner=RippleSpinner(width=80)
)) do session
    return DOM.div("Hello World")
end
```

### How It Works

Under the hood, when `loading_page` is set:

1. An `Observable{Any}` is created with the loading page as its initial value
2. The Observable is rendered into the DOM (using Bonito's reactive subsession system)
3. The app handler runs asynchronously via `@async`
4. Once the handler completes, the Observable is updated with the real DOM
5. Bonito's existing `update_session_dom!` replaces the loading page subsession with the real content

When `loading_page=nothing` (the default), the app renders synchronously as before -- no Observable wrapping occurs.

!!! note "Observables and Widgets"
    All reactive features (Observables, Buttons, Sliders, etc.) work normally inside apps with `loading_page` enabled. The Observable wrapping is transparent to the handler's DOM.

## Connection Indicator

Bonito provides an optional LED-like indicator that can be displayed in the top-right corner to show the connection status to the Julia server:

- **Green**: Connected to the server
- **Yellow**: Connecting or reconnecting
- **Red**: Disconnected from the server
- **Gray**: No connection mode (static export)

### Enabling the Indicator

To show the connection indicator, pass a `ConnectionIndicator()` to your App:

```julia
App(; indicator=ConnectionIndicator()) do
    DOM.h1("App with connection indicator")
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
            onStatusChange: function(status) {
                element.textContent = messages[status] || messages.disconnected;
                element.style.color = colors[status] || colors.disconnected;
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
    onStatusChange: function(status) {
        // status: "connected" | "connecting" | "disconnected" | "no_connection"
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

The indicator automatically shows the appropriate status based on the connection state, including "no_connection" for static exports.
