module DOM

using Hyperscript


function um(tag, args...; kw...)
    m(tag, args...; kw...)
end

function m_unesc(tag, args...; kw...)
    m(Hyperscript.NOESCAPE_HTMLSVG_CONTEXT, tag, args...; kw...)
end

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
    @eval $(node)(args...; kw...) = um($(node_name), args...; kw...)
    @eval $(unesc)(args...; kw...) = m_unesc($(node_name), args...; kw...)
end

style(args...; kw...) = m_unesc("style", args...; kw...)
script(args...; kw...) = m_unesc("script", args...; kw...)

end

using .DOM

function selector(node)
    query_string = "[data-jscall-id=$(repr(uuid(node)))]"
    return js"(document.querySelector($(query_string)))"
end

# default turn attributes into strings
attribute_render(session::Session, parent, attribute::String, x) = string(x)
attribute_render(session::Session, parent, attribute::String, x::Nothing) = x
attribute_render(session::Session, parent, attribute::String, x::Bool) = x

function attribute_render(session::Session, parent, attribute::String, obs::Observable)
    onjs(session, obs, js"value=> JSServe.update_node_attribute($(parent), $attribute, value)")
    return attribute_render(session, parent, attribute, obs[])
end

struct DontEscape
    x::Any
end

function Hyperscript.printescaped(io::IO, x::DontEscape, escapes)
    print(io, x.x)
end

function attribute_render(session::Session, parent, attribute::String, jss::JSCode)
    # add js after parent gets loaded
    func = js"""(node) => {
        node[$attribute] = $(jss)
    }"""
    # preserve func.file
    onload(session, parent, JSCode(func.source, jss.file))
    return ""
end

function attribute_render(session::Session, parent, attribute::String, asset::Asset)
    if parent isa Hyperscript.Node{Hyperscript.CSS}
        # css seems to require an url object
        return "url($(url(session, asset)))"
    else
        return "$(url(session, asset))"
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

    new_attributes = Dict{String, Any}()
    children_changed = false
    attributes_changed = false
    newchildren = map(node_children) do elem
        new_elem = jsrender(session, elem)
        children_changed = children_changed || new_elem !== elem
        return new_elem
    end
    for (k, v) in node_attrs
        rendered = attribute_render(session, node, k, v)
        attributes_changed = attributes_changed || rendered !== v
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
    # Don't copy node if nothing has changed!
    if attributes_changed || children_changed
        return Node(
            Hyperscript.context(node),
            Hyperscript.tag(node),
            newchildren,
            new_attributes)
    else
        return node
    end
end

# jsrender(session, x) will be called anywhere...
# if there is nothing sessions specific in the dom, fallback to jsrender without session
function jsrender(session::Session, node::Node)
    render_node(session, node)
end

function uuid(session::Union{Nothing, Session}, node::Node)
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
    attributes::Dict{String, Any}
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

    new_attributes = Dict{String, Any}()
    newchildren = map(child-> SerializedNode(session, child), node_children)
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
