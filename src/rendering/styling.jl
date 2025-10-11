# For Hyperscript integration
function attribute_render(session::Session, parent, attribute::String, css::CSS)
    if attribute != "style"
        error("`CSS(...)` can only be used for the style attribute! Found: $(attribute) with css:\n $(css)")
    end
    node_styles = get!(session.stylesheets, parent, Set{CSS}())
    push!(node_styles, css)
    return ""
end

function attribute_render(session::Session, parent, attribute::String, styles::Styles)
    if attribute != "style"
        error("`Styles(...)` can only be used for the style attribute! Found: $(attribute) with css:\n $(css)")
    end
    node_styles = get!(session.stylesheets, parent, Set{CSS}())
    union!(node_styles, values(styles.styles))
    return ""
end

function jsrender(session::Session, style::Styles)
    push!(session.global_stylesheets, style)
    return nothing
end

function to_string(session::Session, style::Styles)
    io = IOBuffer()
    for (_, css) in style.styles
        render_style(io, session, "", css)
    end
    return String(take!(io))
end

convert_css_attribute(asset::Asset) = asset
convert_css_attribute(nested::CSS) = nested
convert_css_attribute(attribute::String) = String(chomp(attribute))
convert_css_attribute(color::Symbol) = convert_css_attribute(string(color))
convert_css_attribute(@nospecialize(::Observable)) = error("Observable not supported in CSS attributes right now!")
convert_css_attribute(@nospecialize(any)) = string(any)

function convert_css_attribute(color::Colorant)
    rgba = convert(RGBA{Float64}, color)
    return "rgba($(rgba.r * 255), $(rgba.g * 255), $(rgba.b * 255), $(rgba.alpha))"
end

function render_element(io, session, key, value::String, nesting)
    return println(io, "  "^(nesting), key, ": ", value, ";")
end

function render_element(io, session, key, value::Asset, nesting)
    u = url(session, value)
    return render_element(io, session, key, "url($u)", nesting)
end


function render_element(io, session, key, css::CSS, nesting)
    return render_style(io, session, "", css, nesting + 1)
end

function render_style(io, session, prefix, css::CSS, nesting=1)
    println(io, "  "^(nesting-1), prefix, css.selector, " {")
    for (k, v) in css.attributes
        render_element(io, session, k, v, nesting)
    end
    println(io, "  "^(nesting-1), "}")
end

Base.show(io::IO, css::CSS) = show(io, MIME"text/plain"(), css)

function Base.show(io::IO, ::MIME"text/plain", css::CSS)
    render_style(io, Session(NoConnection(); asset_server=NoServer()), "", css)
end

Base.show(io::IO, styles::Styles) = show(io, MIME"text/plain"(), styles)
function Base.show(io::IO, ::MIME"text/plain", styles::Styles)
    for (selector, css) in styles.styles
        render_style(io, Session(NoConnection(); asset_server=NoServer()), "", css)
    end
end

function render_stylesheets!(root_session, session, stylesheets::Dict{HTMLElement, Set{CSS}})
    combined = Dict{CSS,Set{HTMLElement}}()
    for (node, styles) in stylesheets
        for css in styles
            if haskey(combined, css)
                push!(combined[css], node)
            else
                combined[css] = Set([node])
            end
        end
    end
    io = IOBuffer()
    for (css, nodes) in combined
        idx = root_session.style_counter += 1
        root_session.style_counter
        id = string("style_", idx)
        render_style(io, session, "." * id, css)
        for node in nodes
            attr = Hyperscript.attrs(node)
            attr["class"] = get!(attr, "class", "") * " " * id
        end
    end
    stylesheet = String(take!(io))
    return DOM.style(stylesheet)
end

function CSS(selector::String, args::CSS...)
    return CSS(selector, Dict{String,Any}((arg.selector => arg for arg in args)))
end

function CSS(selector::String, args::Pair...)
    return CSS(selector, Dict{String,Any}(args...))
end
CSS(args::Pair...) = CSS("", args...)


Styles() = Styles(OrderedDict{String,CSS}())
function Styles(css::CSS)
    d = OrderedDict{String,CSS}()
    d[css.selector] = css
    return Styles(d)
end
function Styles(csss::CSS...)
    result = Styles()
    merge!(result, Set(csss))
    return result
end

function Styles(css::CSS, pairs::Pair...)
    error("Style $(css) with $(pairs) unaccaptable!")
end
Styles(pairs::Pair...) = Styles(CSS(pairs...))
function Styles(first::Styles, rest...)
    # Build styles in order: first comes first, then rest are merged in order
    # The LAST argument takes precedence for value conflicts
    result = Styles(copy(first.styles))
    for style in rest
        if style isa Styles
            merge!(result, style)
        else
            # Handle other constructible types
            merge!(result, Styles(style))
        end
    end
    return result
end

function Styles(first::Styles, second::Styles)
    # Merge in order: first appears first, second takes precedence for conflicts
    result = Styles(copy(first.styles))
    merge!(result, second)
    return result
end

function Base.merge(defaults::Styles, priority::Styles) # second argument takes priority
    result = Styles(copy(defaults.styles))
    merge!(result, priority)
    return result
end

function Base.merge!(target::Styles, styles::Set{CSS})
    for css in styles
        selector = css.selector
        if haskey(target.styles, selector)
            target.styles[selector] = merge(target.styles[selector], css)
        else
            target.styles[selector] = css
        end
    end
end

function Base.merge!(defaults::Styles, priority::Styles)
    for (selector, css) in priority.styles
        if haskey(defaults.styles, selector)
            defaults.styles[selector] = merge(defaults.styles[selector], css)
        else
            defaults.styles[selector] = css
        end
    end
end

function Base.merge(a::CSS, b::CSS)
    a.selector == b.selector || error("Can't merge CSS with different selectors: $(a.selector) != $(b.selector)")
    return CSS(a.selector, merge(a.attributes, b.attributes))
end

#=
Decided against this macro, since it adds little value
And only adds confusion, since there are two ways with it to define CSS attributes
Leaving it here in case we find really strong reasons to use it
Two of the main problems in my eyes:
1) Without using strings as keys we cant directly use attributes like `font-size` and need to have some rewriting logic e.g. from `font_size` to `font-size`.
2) With using strings we get super close to just the dict syntax of `Dict("font-size" => "12px")` and the macro is not really needed anymore.

macro CSS(curly)
    if  curly.head !== :bracescat
        error("use @CSS {...}")
    end
    css = Dict{String, Any}()
    for arg in curly.args
        if Meta.isexpr(arg, :call) && length(arg.args) !== 3 && arg.args[1] !== Symbol(":")
            error("use @CSS {key: value; key2: value2}")
        end
        key = replace(string(arg.args[2]), "_" => "-")
        value = arg.args[3]
        css[key] = value
    end
    return CSS(css)
end
=#
