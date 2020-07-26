function DIV(args...; kw...)
    return Hyperscript.m("div", args...; kw...)
end

# Implement AbstractTree interface
AbstractTrees.children(node::JSON3.Object) = [get(node, :children, Any[])...]

match_node(a, b) = (a == b)
function match_node(node::JSON3.Object, pattern::NamedTuple)
    return all(pairs(pattern)) do (k, v)
        haskey(node, k) || return false
        return match_node(node[k], v)
    end
end

function match_node(node::AbstractVector, pattern::AbstractVector)
    length(node) != length(pattern) && return false
    return all(match_node.(node, pattern))
end

function match_node(node, pattern::Function)
    return pattern(node)
end

function find_by_attributes(root, attrs)
    for x in PreOrderDFS(root)
        match_node(x, attrs) && return x
    end
end

function find_all_attributes(root, attrs)
    result = []
    for x in PreOrderDFS(root)
        if match_node(x, attrs)
            push!(result, x)
        end
    end
    return result
end

find_by_type(root, type) = find_by_attributes(root, (type = type,))
find_by_name(root, name) = find_by_attributes(root, (name = name,))

const color_name_lookup = Dict(zip(values(Colors.color_names), keys(Colors.color_names)))

function to_color_name(rgb...)
    rgb_i = round.(Int, rgb .* 255)
    return get(color_name_lookup, rgb_i) do
        return "#" * lowercase(hex(RGB(rgb...)))
    end
end

node2id(node) = replace(lowercase(node.type) * "_" * node.id, r"[\.: ]" => "_")

function to_color(c)
    to_c(x) = round(Int, x * 255)
    r, g, b, a = c[:r], c[:g], c[:b], c[:a]
    if all(x-> x ≈ 0, (r, g, b, a))
        return nothing
    end
    if a < 1.0
        return "rgba($(to_c(r)), $(to_c(g)), $(to_c(b)), $(round(a, digits=2)))"
    else
        return "#" * lowercase(hex(RGB(r, g, b)))
    end
end

unique_styles = Dict{NamedTuple, String}()
name2styles = Dict{String, Set{String}}()
per_object_styles = Dict()
_unique_names = Set{Symbol}()

function reset_styles!()
    foreach(empty!, (_unique_names, per_object_styles, unique_styles,
                     name2styles))
end

function text_transform(node)
    haskey(node, :style) || return nothing
    haskey(node.style, :textCase) || return nothing
    value = node.style.textCase == "UPPER" ? "uppercase" : "lowercase"
    return Dict(:textTransform => value)
end

function text_size(node)
    haskey(node, :style) || return nothing
    haskey(node.style, :fontSize) || return nothing
    # standard font size:
    node.style.fontSize == 16 && return nothing
    return Dict(:fontSize => "$(node.style.fontSize)px")
end

function text_weight(node)
    haskey(node, :style) || return nothing
    haskey(node.style, :fontWeight) || return nothing
    weight = node.style.fontWeight
    weight == 400 && return nothing # 400 is the default
    return Dict(:fontWeight => string(weight))
end

function font_family(node)
    haskey(node, :style) || return nothing
    haskey(node.style, :fontFamily) || return nothing
    return Dict(:fontFamily => node.style.fontFamily)
end

function text_classes(node)
    classes = String[]
    insert_style!(classes, effect2css(node))
    insert_style!(classes, fills2css(node))
    insert_style!(classes, text_size(node))
    insert_style!(classes, text_transform(node))
    insert_style!(classes, text_weight(node))
    insert_style!(classes, font_family(node))
    return classes
end

function class(parent, node)
    classes = unique(to_css(parent, node))
    push!(classes, lowercase(node.type))
    return join(classes, " ")
end

function unique_names(name)
    idx = 0
    oname = name
    while name in _unique_names
        idx += 1
        name = Symbol("$(oname)_$idx")
    end
    push!(_unique_names, name)
    return string(name)
end

# Make it easier to ignore nothing!
insert_style!(classes, ::Nothing) = nothing
function insert_style!(classes, style)
    for (k, v) in pairs(style)
        style = NamedTuple{(k,)}((v,))
        name = get!(unique_styles, style) do
            unique_names(k)
        end
        push!(classes, name)
    end
end

is_invisible(node) = haskey(node, :visible) && !node.visible
function fill2css(node, fill)
    if fill.type == "GRADIENT_LINEAR"
        points = map(x-> Float64[x.x, x.y], fill.gradientHandlePositions)
        p1, p2 = points[1], points[end]
        len = norm(p1 .- p2)
        diff = p2 .- p1
        angle = "$(round(atan(diff[2], diff[1]) * 180.0 / π, digits=2))deg"
        colors = map(fill.gradientStops) do stop
            p = points[stop.position + 1]
            percent = round((norm(p) / len) * 100, digits=1)
            c = to_color(stop.color)
            "$c $(percent)%"
        end
        return (:background, "linear-gradient($angle, $(join(colors, ",")))")
    elseif fill.type == "SOLID"
        if haskey(fill, :color)
            color = copy(fill.color)
            if haskey(fill, :opacity)
                color[:a] = fill.opacity
            end
            css_color = to_color(color)
            if css_color !== nothing
                if node.type in ("LINE", "RECTANGLE")
                    return (:backgroundColor, css_color)
                else
                    return (:color, css_color)
                end
            end
        end
    end
    return nothing
end

function fills2css(node)
    fills = Dict{Symbol, String}()
    for fill in node.fills
        # filter out invisibles
        is_invisible(fill) && continue
        k_v = fill2css(node, fill)
        k_v == nothing && continue
        fills[k_v[1]] = k_v[2]
    end
    isempty(fills) && return nothing
    return fills
end

function effect2css(node)
    shadows = String[]
    for effect in node.effects
        # filter out invisible effects
        is_invisible(effect) && continue
        # That's what we need & support right now
        if effect.type in ("DROP_SHADOW", "INNER_SHADOW")
            r = effect.radius
            x = effect.offset.x
            y = effect.offset.y
            c = to_color(effect.color)
            typ = effect.type == "DROP_SHADOW" ? "" : "inset "
            push!(shadows, "$(typ)$(x)px $(y)px $(r)px $(c)")
        end
    end
    isempty(shadows) && return nothing
    return Dict(:boxShadow => join(shadows, ","))
end

function stroke2css(node)
    strokes = Dict{Symbol, String}()
    # line strokes are handled elsewhere
    if node.type == "LINE"
        # Lines get drawn as filled divs, so instead of stroking, we
        # fill them with the stroke :-O
        x = fill2css(node, node.strokes[1])
        strokes[x[1]] = x[2]
        return strokes
    end
    visibles = filter((!)∘is_invisible, node.strokes)
    if length(visibles) > 1
        @warn "multiple strokes aren't supported. Node: $(node.name)"
    end
    isempty(visibles) && return nothing
    for stroke in visibles
        is_invisible(stroke) && continue
        typ = lowercase(stroke.type)
        c_a = copy(stroke.color)
        if haskey(stroke, :opacity)
            c_a[:a] = stroke.opacity
        end
        c = to_color(c_a)
        w = node.strokeWeight
        strokes[:border] = "$(w)px $(typ) $(c)"
    end
    return strokes
end

function opacity2css(node)
    return nothing
    haskey(node, :opacity) || return nothing
    return Dict(:opacity => string(round(node.opacity, digits=2)))
end

function border_radius2css(node)
    haskey(node, :cornerRadius) || return nothing
    return Dict(:borderRadius => "$(node.cornerRadius)px")
end

function backgroundcolor(node)
    haskey(node, :backgroundColor) || return nothing
    c = to_color(node.backgroundColor)
    c === nothing && return nothing
    return Dict(:backgroundColor => c)
end

function transform2css(node)
    haskey(node, :relativeTransform) || return nothing
    trans = node.relativeTransform
    # Uh, this seems wrong, but works?! xD
    a, b, xt = trans[1]
    angle = round(Int, atan(-b, a) * 180/π)
    angle == 0 && return nothing
    return Dict(:transform => "rotate($(angle)deg)")
end

merge_styles(styles) = merge(filter((!)∘isnothing, styles)...)

function style2css(node)
    haskey(node, :style) || return nothing
    styles = [effect2css(node), stroke2css(node),
              opacity2css(node), border_radius2css(node),
              backgroundcolor(node),
              text_size(node), text_transform(node),
              font_family(node), text_weight(node)]
    if node.type == "RECTANGLE"
        push!(styles, fills2css(node))
    end
    x = merge_styles(styles)
    isempty(x) && return
    return x
end

function boundingbox2css(parent, node)
    bb = node.absoluteBoundingBox
    width = round(Int, bb.width)
    height = round(Int, bb.height)
    attrs = Dict{Symbol, Any}()
    if node.type == "LINE"
        # Somehow sometimes one of the dims are 0 for lines
        # which should be the stroke width... Other times
        # it's the actual strokewidth... No idea when
        # But just making it at least the strokewidth seems to work well!
        attrs[:width] = "$(max(width, node.strokeWeight))px"
        attrs[:height] = "$(max(height, node.strokeWeight))px"
    else
        attrs[:width] = "$(width)px"
        attrs[:height] = "$(height)px"
    end
    if parent !== nothing && !(node.type in ("GROUP",))
        pb = parent.absoluteBoundingBox
        attrs[:left] = "$(round(Int, bb.x - pb.x))px"
        attrs[:top] = "$(round(Int, bb.y - pb.y))px"
    end
    if !isempty(attrs)
        per_object_styles[node2id(node)] = attrs
    end
    return attrs
end

function to_css(parent, node)
    # adds the personal style to global per_object_style
    boundingbox2css(parent, node)
    css_classes = String[]
    if node.type !== "LINE"
        # Lines get drawn transformed already somehow
        insert_style!(css_classes, transform2css(node))
    end
    insert_style!(css_classes, effect2css(node))
    insert_style!(css_classes, fills2css(node))
    insert_style!(css_classes, stroke2css(node))
    insert_style!(css_classes, opacity2css(node))
    insert_style!(css_classes, border_radius2css(node))
    insert_style!(css_classes, backgroundcolor(node))
    insert_style!(css_classes, style2css(node))
    return css_classes
end

function emit_path(io, node, geom, fill)
    haskey(geom, :visible) && !geom.visible && return
    haskey(fill, :type) && fill.type == "IMAGE" && return
    c = ""
    if haskey(fill, :color)
        color = copy(fill.color)
        # Sigh, why aren't they consistent about this?!
        haskey(node, :opacity) && (color[:a] = node.opacity)
        haskey(fill, :opacity) && (color[:a] = fill.opacity)
        c = "fill=$(repr(to_color(color)))"
    end
    winding = ""
    if haskey(geom, :windingRule)
        w = repr(lowercase(geom.windingRule))
        winding = "fill-rule=$(w) clip-rule=$(w)"
    end
    println(io, "<path $(winding) d=$(repr(geom.path)) $c/>")
end

function effect2filter(node)
    effects = effect2css(node)
    effects == nothing && return nothing
    return Dict(:filter => "drop-shadow($(effects[:boxShadow]));")
end

function to_svg_node(paths, css_classes)
    return DOM.svg_unesc(paths; xmlns="http://www.w3.org/2000/svg", class=join(css_classes, " "), style="overflow: visible")
end

function vector_node(parent, node)
    paths = sprint() do io
        for (stroke_geom, stroke) in zip(node.strokeGeometry, node.strokes)
            emit_path(io, node, stroke_geom, stroke)
        end
        for (fill_geom, fill) in zip(node.fillGeometry, node.fills)
            emit_path(io, node, fill_geom, fill)
        end
    end
    boundingbox2css(parent, node)
    layout = lowercase.(values(node.constraints))
    insert_style!(layout, transform2css(node))
    push!(layout, node2id(node))
    css_classes = String[]
    css_classes = String[]
    insert_style!(css_classes, opacity2css(node))
    insert_style!(css_classes, effect2filter(node))
    svg = to_svg_node(paths, css_classes)
    return DIV(svg, class=join(layout, " "))
end


function to_html(parent, node; replacements = Dict())
    haskey(replacements, node.name) && return replacements[node.name](parent, node)
    is_invisible(node) && return nothing
    html_node = if node.type == "GROUP"
        DIV(to_html.((parent,), node.children)...)
    elseif node.type == "FRAME"
        DIV(to_html.((node,), node.children)...)
    elseif node.type == "TEXT"
        DIV(node.characters)
    elseif node.type == "RECTANGLE"
        DIV()
    elseif node.type == "LINE"
        DIV()
    else
        # the rest are polys, which can all (most?) be represented by the vector node
        return vector_node(parent, node)
    end
    Hyperscript.attrs(html_node)["class"] = class(parent, node) * " " * node2id(node)
    # Hyperscript.attrs(html_node)["id"] = node2id(node)
    return html_node
end

function extract_styles()
    ustyles = sort(collect(unique_styles), by=last)
    css = map(ustyles) do (k, v)
        DOM.css("." * v; k...)
    end
    ostyles = sort(collect(per_object_styles), by=first)
    css2 = map(ostyles) do (k, v)
        DOM.css("." * k; v...)
    end
    unique_styles_rev = Dict(zip(values(unique_styles), keys(unique_styles)))

    return DOM.style(css..., css2...)
end
