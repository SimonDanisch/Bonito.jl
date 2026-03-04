using ANSIColoredPrinters: HTMLPrinter

const ANSI_CSS = Styles(
    # ANSI color variables for light theme
    CSS(
        "@media (prefers-color-scheme: light)",
        CSS(
            ":root",
            "--ansi-black" => "#000000",
            "--ansi-red" => "#cd3131",
            "--ansi-green" => "#00bc00",
            "--ansi-yellow" => "#949800",
            "--ansi-blue" => "#0451a5",
            "--ansi-magenta" => "#bc05bc",
            "--ansi-cyan" => "#0598bc",
            "--ansi-white" => "#555555",
            "--ansi-bright-black" => "#686868",
            "--ansi-bright-red" => "#ff5555",
            "--ansi-bright-green" => "#55ff55",
            "--ansi-bright-yellow" => "#ffff55",
            "--ansi-bright-blue" => "#5555ff",
            "--ansi-bright-magenta" => "#ff55ff",
            "--ansi-bright-cyan" => "#55ffff",
            "--ansi-bright-white" => "#ffffff"
        )
    ),
    # ANSI color variables for dark theme
    CSS(
        "@media (prefers-color-scheme: dark)",
        CSS(
            ":root",
            "--ansi-black" => "#000000",
            "--ansi-red" => "#f44747",
            "--ansi-green" => "#4ec9b0",
            "--ansi-yellow" => "#dcdcaa",
            "--ansi-blue" => "#569cd6",
            "--ansi-magenta" => "#c678dd",
            "--ansi-cyan" => "#56b6c2",
            "--ansi-white" => "#d4d4d4",
            "--ansi-bright-black" => "#808080",
            "--ansi-bright-red" => "#ff6b6b",
            "--ansi-bright-green" => "#6bffb8",
            "--ansi-bright-yellow" => "#ffffa0",
            "--ansi-bright-blue" => "#7cc3ff",
            "--ansi-bright-magenta" => "#ff8cff",
            "--ansi-bright-cyan" => "#8cffff",
            "--ansi-bright-white" => "#ffffff"
        )
    ),
    # Text formatting (SGR codes)
    CSS("span.sgr1", "font-weight" => "bolder"),
    CSS("span.sgr2", "font-weight" => "lighter"),
    CSS("span.sgr3", "font-style" => "italic"),
    CSS("span.sgr4", "text-decoration" => "underline"),
    CSS("span.sgr7", "color" => "var(--bg-primary)", "background-color" => "var(--text-primary)"),
    CSS("span.sgr8, span.sgr8 span, span span.sgr8", "color" => "transparent"),
    CSS("span.sgr9", "text-decoration" => "line-through"),
    # Standard foreground colors (30-37)
    CSS("span.sgr30", "color" => "var(--ansi-black)"),
    CSS("span.sgr31", "color" => "var(--ansi-red)"),
    CSS("span.sgr32", "color" => "var(--ansi-green)"),
    CSS("span.sgr33", "color" => "var(--ansi-yellow)"),
    CSS("span.sgr34", "color" => "var(--ansi-blue)"),
    CSS("span.sgr35", "color" => "var(--ansi-magenta)"),
    CSS("span.sgr36", "color" => "var(--ansi-cyan)"),
    CSS("span.sgr37", "color" => "var(--ansi-white)"),
    # Background colors (40-47)
    CSS("span.sgr40", "background-color" => "var(--ansi-black)"),
    CSS("span.sgr41", "background-color" => "var(--ansi-red)"),
    CSS("span.sgr42", "background-color" => "var(--ansi-green)"),
    CSS("span.sgr43", "background-color" => "var(--ansi-yellow)"),
    CSS("span.sgr44", "background-color" => "var(--ansi-blue)"),
    CSS("span.sgr45", "background-color" => "var(--ansi-magenta)"),
    CSS("span.sgr46", "background-color" => "var(--ansi-cyan)"),
    CSS("span.sgr47", "background-color" => "var(--ansi-white)"),
    # Bright foreground colors (90-97)
    CSS("span.sgr90", "color" => "var(--ansi-bright-black)"),
    CSS("span.sgr91", "color" => "var(--ansi-bright-red)"),
    CSS("span.sgr92", "color" => "var(--ansi-bright-green)"),
    CSS("span.sgr93", "color" => "var(--ansi-bright-yellow)"),
    CSS("span.sgr94", "color" => "var(--ansi-bright-blue)"),
    CSS("span.sgr95", "color" => "var(--ansi-bright-magenta)"),
    CSS("span.sgr96", "color" => "var(--ansi-bright-cyan)"),
    CSS("span.sgr97", "color" => "var(--ansi-bright-white)"),
    # Bright background colors (100-107)
    CSS("span.sgr100", "background-color" => "var(--ansi-bright-black)"),
    CSS("span.sgr101", "background-color" => "var(--ansi-bright-red)"),
    CSS("span.sgr102", "background-color" => "var(--ansi-bright-green)"),
    CSS("span.sgr103", "background-color" => "var(--ansi-bright-yellow)"),
    CSS("span.sgr104", "background-color" => "var(--ansi-bright-blue)"),
    CSS("span.sgr105", "background-color" => "var(--ansi-bright-magenta)"),
    CSS("span.sgr106", "background-color" => "var(--ansi-bright-cyan)"),
    CSS("span.sgr107", "background-color" => "var(--ansi-bright-white)"),
    # Whitespace handling
    CSS(".terminal-output", "white-space" => "pre-wrap")
)

"""
    RichText(data::Vector{UInt8})
    RichText(str::String)

A type wrapping bytes or a string that may contain ANSI escape codes.
When rendered in Bonito, ANSI codes are converted to styled HTML via ANSIColoredPrinters.
"""
struct RichText
    data::Vector{UInt8}
end

RichText(str::String) = RichText(Vector{UInt8}(str))

"""
    ansi_to_html(bytes::AbstractVector{UInt8}) -> String

Convert raw bytes containing ANSI escape codes to an HTML string
using ANSIColoredPrinters.HTMLPrinter.
"""
function ansi_to_html(bytes::AbstractVector{UInt8})
    printer = HTMLPrinter(IOBuffer(bytes); root_tag="span")
    return sprint(io -> show(io, MIME"text/html"(), printer))
end

ansi_to_html(str::String) = ansi_to_html(Vector{UInt8}(str))

"""
    has_ansi_codes(str::AbstractString) -> Bool

Check whether a string contains ANSI escape sequences.
"""
has_ansi_codes(str::AbstractString) = occursin(r"\e\[", str)

function jsrender(session::Session, rt::RichText)
    html_str = ansi_to_html(rt.data)
    return jsrender(session, DOM.div(
        ANSI_CSS,
        HTML(html_str);
        class="terminal-output"
    ))
end

"""
    TerminalOutput(; style=Styles())

A widget for displaying terminal output with ANSI color support.
Supports two modes:

1. **Static**: Render a `RichText` value directly.
2. **Streaming**: Push new content incrementally via the `content` observable.

Use `push!(widget, bytes)` or `push!(widget, str)` to append content,
and `empty!(widget)` to clear.

## Example

```julia
# Static rendering
output = TerminalOutput()
push!(output, "\\e[32mHello\\e[0m \\e[31mWorld\\e[0m")

# Or render directly from RichText
jsrender(session, RichText("\\e[1mbold text\\e[0m"))
```
"""
struct TerminalOutput
    content::Observable{String}
    style::Styles
end

function TerminalOutput(; style=Styles())
    return TerminalOutput(Observable(""), style)
end

function TerminalOutput(rt::RichText; style=Styles())
    widget = TerminalOutput(; style)
    push!(widget, rt.data)
    return widget
end

function Base.push!(widget::TerminalOutput, bytes::AbstractVector{UInt8})
    if !isempty(bytes)
        html_str = ansi_to_html(bytes)
        widget.content[] = widget.content[] * html_str
    end
    return widget
end

function Base.push!(widget::TerminalOutput, str::String)
    return push!(widget, Vector{UInt8}(str))
end

"""
    append_html!(widget::TerminalOutput, html::String)

Append pre-converted HTML directly to the widget's content.
Use this when ANSI-to-HTML conversion has already been performed (e.g. by `ansi_to_html`).
"""
function append_html!(widget::TerminalOutput, html::String)
    if !isempty(html)
        widget.content[] = widget.content[] * html
    end
    return widget
end

function Base.empty!(widget::TerminalOutput)
    widget.content[] = ""
    return widget
end

function jsrender(session::Session, widget::TerminalOutput)
    html_obs = Observable(HTML(""))
    on(widget.content) do str
        isempty(str) && return
        html_obs[] = HTML(str)
    end
    # Trigger initial render if content is non-empty
    if !isempty(widget.content[])
        html_obs[] = HTML(widget.content[])
    end
    return jsrender(session, DOM.div(
        ANSI_CSS,
        html_obs;
        class="terminal-output",
        style=widget.style
    ))
end
