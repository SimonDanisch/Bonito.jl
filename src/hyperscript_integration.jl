

module DOM

using Hyperscript

const global_unique_dom_id_counter = Ref(0)

"""
    get_unique_dom_id()

We could use a unique ID like uuid4, but since every dom element gets
such an id, I prefer to keep the id as short as possible, so we just use a counter.
"""
function get_unique_dom_id()
    global_unique_dom_id_counter[] += 1
    return string(global_unique_dom_id_counter[])
end

"""
Dome node with unique ID, to make it easier to interpolate it.
"""
function um(tag, args...; kw...)
    m(tag, args..., dataJscallId = get_unique_dom_id(); kw...)
end

function m_unesc(tag, args...; kw...)
    m(Hyperscript.NOESCAPE_HTMLSVG_CONTEXT, tag, args..., dataJscallId = get_unique_dom_id(); kw...)
end

p(args...; kw...) = um("p", args...; kw...)
div(args...; kw...) = um("div", args...; kw...)
div_unesc(args...; kw...) = m_unesc("div", args...; kw...)
input(args...; kw...) = um("input", args...; kw...)
font(args...; kw...) = um("font", args...; kw...)

style(args...; kw...) = m(Hyperscript.NOESCAPE_HTMLSVG_CONTEXT, "style", args...; kw...)
script(args...; kw...) = m(Hyperscript.NOESCAPE_HTMLSVG_CONTEXT, "script", args...; kw...)

end

using .DOM

# default turn attributes into strings
attribute_render(session, parent, attribute, x) = string(x)
function attribute_render(session, parent, attribute, obs::Observable)
    onjs(session, obs, js"""
    function (value){
        var node = $(parent);
        if(node){
            if(node[$attribute] != value){
                node[$attribute] = value;
            }
            return true;
        }else{
            return false; //deregister
        }
    }
    """)
    return attribute_render(session, parent, attribute, obs[])
end

function attribute_render(session, parent, attribute, jss::JSCode)
    return serialize_string(jss)
end

render_node(session::Session, x) = x

function render_node(session::Session, node::Node{Hyperscript.CSS})
# do nothing
    return node
end
function render_node(session::Session, node::Node)
    # give each node a unique id inside the dom
    new_attributes = Dict{String, Any}()
    newchildren = map(children(node)) do elem
        childnode = jsrender(session, elem)
        # if a transform elem::Any -> ::Node happens, we need to
        # render the resulting node again, since the attr/children won't be
        # lowered yet!
        if !(elem isa Node)
            childnode = render_node(session, childnode)
        end
        return childnode
    end
    for (k, v) in Hyperscript.attrs(node)
        new_attributes[k] = attribute_render(session, node, k, v)
    end
    return Node(
        Hyperscript.context(node),
        Hyperscript.tag(node),
        newchildren,
        new_attributes
    )
end

# jsrender(session, x) will be called anywhere...
# if there is nothing sessions specific in the dom, fallback to jsrender without session
function jsrender(session::Session, node::Node)
    render_node(session, node)
end

function uuid(node::Node)
    get(Hyperscript.attrs(node), "data-jscall-id") do
        error("Node $(node) doesn't have a unique id. Make sure to use DOM.$(Hyperscript.tag(node))")
    end
end

# Handle interpolating into Javascript
function serialize_string(io::IO, node::Node)
    # This relies on jsrender to give each node a unique id under the
    # attribute data-jscall-id. This is a bit brittle
    # improving this would be nice
    print(io, "(document.querySelector('[data-jscall-id=$(repr(uuid(node)))]'))")
end



"""
    jsrender([::Session], x::Any)
Internal render method to create a valid dom. Registers used observables with a session
And makes sure the dom only contains valid elements. Overload jsrender(::YourType)
To enable putting YourType into a dom element/div.
You can also overload it to take a session as first argument, to register
messages with the current web session (e.g. via onjs).
"""
jsrender(::Session, x::Any) = jsrender(x)
jsrender(::Session, x::Union{Symbol, String}) = DOM.p(string(x))

jsrender(::Session, x::String) = x
jsrender(::Session, x::Hyperscript.Styled) = x
