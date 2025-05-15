module DOM

using Hyperscript

for node in [:a, :abbr, :address, :area, :article, :aside, :audio, :b,
    :base, :bdi, :bdo, :blockquote, :body, :br, :button, :canvas,
    :code, :col, :colgroup, :data, :datalist, :caption, :cite,
    :dd, :del, :details, :dfn, :dialog, :div, :dl, :dt, :em, :embed,
    :figcaption, :figure, :footer, :form, :h1, :h2, :fieldset,
    :h3, :h4, :h5, :h6, :head, :header, :hgroup, :hr, :html, :i, :iframe,
    :input, :ins, :kbd, :label, :legend, :li, :link, :img,
    :main, :map, :mark, :math, :menu, :menuitem, :meta, :meter, :nav,
    :object, :ol, :optgroup, :option, :output, :p, :param, :noscript,
    :picture, :pre, :progress, :q, :rb, :rp, :rt, :rtc, :ruby, :s, :samp,
    :section, :select, :slot, :small, :source, :span,
    :strong, :sub, :summary, :sup, :svg, :table, :tbody, :td, :template,
    :textarea, :tfoot, :th, :thead, :time, :title, :tr,
    :track, :u, :ul, :var, :video, :wbr, :font]

    node_name = string(node)
    unesc = Symbol(node_name * "_unesc")
    @eval $(node)(args...; kw...) = m($(node_name), args...; kw...)
    @eval $(unesc)(args...; kw...) = m(Hyperscript.NOESCAPE_HTMLSVG_CONTEXT, $(node_name), args...; kw...)
end

style(args...; kw...) = m(Hyperscript.NOESCAPE_HTMLSVG_CONTEXT, "style", args...; kw...)
script(args...; kw...) = m(Hyperscript.NOESCAPE_HTMLSVG_CONTEXT, "script", args...; kw...)
Base.@deprecate um(tag, args...; kw...) m(tag, args...; kw...)

function m_unesc(tag, args...; kw...)
    m(Hyperscript.NOESCAPE_HTMLSVG_CONTEXT, tag, args...; kw...)
end

end

using .DOM

module SVG
# Sadly, SVG isn't that easy to serialize, since it shares tags with HTML,
# but needs to be created via createElementNS. See: http://zhangwenli.com/blog/2017/07/26/createelementns/
# Since it's hard to recognize when to use `createElementNS`, we just make users use `SVG.tagname` to create SVG,
# so we can deserialize it correctly in JS!

using Hyperscript

const SVG_TAGS = [
    :a, :animate, :animateMotion, :animateTransform, :circle, :clipPath, :defs, :desc,
    :discard, :ellipse, :feBlend, :feColorMatrix, :feComponentTransfer, :feComposite, :feConvolveMatrix, :feDiffuseLighting,
    :feDisplacementMap, :feDistantLight, :feDropShadow, :feFlood, :feFuncA, :feFuncB, :feFuncG, :feFuncR,
    :feGaussianBlur, :feImage, :feMerge, :feMergeNode, :feMorphology, :feOffset, :fePointLight, :feSpecularLighting, :feSpotLight,
    :feTile, :feTurbulence, :filter, :foreignObject, :g, :image, :line, :linearGradient,
    :marker, :mask, :metadata, :mpath, :path, :pattern, :polygon, :polyline,
    :radialGradient, :rect, :script, :set, :stop, :style, :svg, :switch, :symbol, :text, :textPath, :title, :tspan, :use, :view,
]

# Tags deprecated by W3 spec
const DEPRECATED_TAGS = [
    :altGlyph, :altGlyphDef, :altGlyphItem, :cursor, Symbol("font-face-format"), Symbol("font-face-name"), Symbol("font-face-src"),
    Symbol("font-face-uri"), Symbol("font-face"), :font, :glyphRef, :hkern, :glyph, Symbol("missing-glyph"), :tref, :vkern,
]

for tag in SVG_TAGS
    @eval $(tag)(args...; kw...) = m($(string(tag)), args...; juliasvgnode=true, kw...)
end

for tag in DEPRECATED_TAGS
    @eval function $(tag)(args...; kw...)
        @warn($("tag $(tag) is deprecated by the SVG standard. It's highly recommend to avoid it."))
        return m($(string(tag)), args...; juliasvgnode=true, kw...)
    end
end

end

using .SVG

function selector(node)
    query_string = "[data-jscall-id=$(repr(uuid(node)))]"
    return js"(document.querySelector($(query_string)))"
end

# default turn attributes into strings
attribute_render(session::Session, parent, attribute::String, x) = string(x)
attribute_render(session::Session, parent, attribute::String, x::Nothing) = x
attribute_render(session::Session, parent, attribute::String, x::Bool) = x


function attribute_render(session::Session, parent, attribute::String, obs::Observable)
    rendered = map(session, obs) do value
        attribute_render(session, parent, attribute, value)
    end
    onjs(session, rendered, js"value=> Bonito.update_node_attribute($(parent), $attribute, value)")
    return rendered[]
end

struct DontEscape
    x::Any
end

function Hyperscript.printescaped(io::IO, x::DontEscape, escapes)
    print(io, x.x)
end

function attribute_render(session::Session, parent, attribute::String, jss::JSCode)
    # add js after parent gets loaded
    func = js"""(() => {
        $(parent)[$attribute] = $(jss)
    })()"""
    # preserve func.file
    evaljs(session, JSCode(func.source, jss.file))
    return ""
end

function attribute_render(session::Session, parent, ::String, asset::AbstractAsset)
    if parent isa Hyperscript.Node{Hyperscript.CSS}
        # css seems to require an url object
        return "url($(url(session, asset)))"
    else
        return url(session, asset)
    end
end

render_node(session::Session, x) = x

const BOOLEAN_ATTRIUTES = Set([
    "allowfullscreen",
    "allowpaymentrequest",
    "async",
    "autofocus",
    "autoplay",
    "checked",
    "controls",
    "default",
    "defer",
    "disabled",
    "formnovalidate",
    "hidden",
    "ismap",
    "itemscope",
    "loop",
    "multiple",
    "muted",
    "nomodule",
    "novalidate",
    "open",
    "readonly",
    "required",
    "reversed",
    "selected",
    "typemustmatch"
])

is_boolean_attribute(attribute::String) = attribute in BOOLEAN_ATTRIUTES

function render_node(session::Session, node::Node)
    # give each node a unique id inside the dom
    node_children = children(node)
    # this could be uuid!, since it adds a uuid if not present
    # we didn't add a `!` since from the user perspective it should be treated as non mutating
    # Anyways, calling it here makes sure, that every rendered node has a unique id we can
    # use for e.g. `evaljs(session, js"$(node)")`
    # It's important that the uuid gets added before rendering because otherwise `evaljs(session, js"$(node)")`
    # won't work in a dynamic context
    uuid(session, node)
    node_attrs = Hyperscript.attrs(node)
    isempty(node_children) && isempty(node_attrs) && return node

    new_attributes = Dict{String,Any}()
    newchildren = []
    for elem in node_children
        new_elem = jsrender(session, elem)
        !isnothing(new_elem) && push!(newchildren, new_elem)
    end
    new_attributes["data-jscall-id"] = uuid(session, node)
    new_node = Node(Hyperscript.context(node),
                    Hyperscript.tag(node),
                    newchildren,
                    new_attributes)
    for (k, v) in node_attrs
        rendered = attribute_render(session, new_node, k, v)
        # We code nothing to mean omitting the attribute!
        if is_boolean_attribute(k)
            if rendered isa Bool
                if rendered
                    # only add attribute if true!
                    new_attributes[k] = true
                end
            else
                error("Boolean attribute $(k) expects a boolean! Found: $(typeof(rendered))")
            end
        else
            new_attributes[k] = rendered
        end
    end
    return new_node
end

# jsrender(session, x) will be called anywhere...
# if there is nothing sessions specific in the dom, fallback to jsrender without session
function jsrender(session::Session, node::Node)
    render_node(session, node)
end

function uuid(session::Union{Nothing,Session}, node::Node)
    return get!(Hyperscript.attrs(node), "data-jscall-id") do
        if isnothing(session)
            return string(rand(UInt64))
        else
            root = root_session(session) # counter needs to be unique to root session
            root.dom_uuid_counter += 1
            return string(root.dom_uuid_counter)
        end
    end
end

jsrender(x::Hyperscript.Styled) = x

struct SerializedNode
    tag::String
    children::Vector{Any}
    attributes::Dict{String,Any}
end

function SerializedNode(session::Session, any)
    node = jsrender(session, any)
    if node isa Node
        return SerializedNode(session, node)
    else
        return node
    end
end

function SerializedNode(session::Session, node::Node)
    # give each node a unique id inside the dom
    node_children = children(node)
    uuid(session, node)
    node_attrs = Hyperscript.attrs(node)

    tag = Hyperscript.tag(node)

    isempty(node_children) && isempty(node_attrs) && return SerializedNode(tag, node_children, node_attrs)

    new_attributes = Dict{String,Any}()
    newchildren = []
    for child in node_children
        node = jsrender(session, child)
        if node isa Node
            push!(newchildren, SerializedNode(session, node))
        elseif !isnothing(node)
            push!(newchildren, node)
        end
    end
    for (k, v) in node_attrs
        rendered = attribute_render(session, node, k, v)
        # We code nothing to mean omitting the attribute!
        if is_boolean_attribute(k)
            if rendered isa Bool
                if rendered
                    # only add attribute if true!
                    new_attributes[k] = true
                end
            else
                error("Boolean attribute $(k) expects a boolean! Found: $(typeof(rendered))")
            end
        else
            new_attributes[k] = rendered
        end
    end
    return SerializedNode(tag, newchildren, new_attributes)
end
