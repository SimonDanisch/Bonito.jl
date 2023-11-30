# For Hyperscript integration
function attribute_render(session::Session, parent, attribute::String, css::CSS)
    if attribute != "style"
        error("`CSS(...)` can only be used for the style attribute! Found: $(attribute) with css:\n $(css)")
    end
    session.stylesheets[parent] = css
    return ""
end

convert_css_attribute(attribute::String) = chomp(attribute)
convert_css_attribute(color::Symbol) = convert_css_attribute(string(color))
convert_css_attribute(@nospecialize(obs::Observable)) = convert_css_attribute(obs[])
convert_css_attribute(@nospecialize(any)) = string(any)

function convert_css_attribute(color::Colorant)
    rgba = convert(RGBA{Float64}, color)
    return "rgba($(rgba.r * 255), $(rgba.g * 255), $(rgba.b * 255), $(rgba.alpha))"
end

function render_style(io, id, css)
    println(io, ".$id {")
    for (k, v) in css.attributes
        println(io, "  ", k, ": ", convert_css_attribute(v), ";")
    end
    println(io, "}")
end

function render_stylesheets(stylesheets::Dict{HTMLElement, CSS})
    combined = Dict{CSS,Vector{HTMLElement}}()
    for (node, css) in stylesheets
        if haskey(combined, css)
            push!(combined[css], node)
        else
            combined[css] = [node]
        end
    end
    io = IOBuffer()
    for (css, nodes) in combined
        id = string("css_", uuid4())
        render_style(io, id, css)
        for node in nodes
            attr = Hyperscript.attrs(node)
            attr["class"] = get!(attr, "class", "") * " " * id
        end
    end
    stylesheet = String(take!(io))
    return DOM.style(stylesheet)
end

function CSS(args::Pair...)
    return CSS(Dict{String,Any}(args...))
end

function CSS(style::CSS, args::Pair...)
    css = Dict{String,Any}(args...)
    merge!(css, style.attributes)
    return CSS(css)
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
