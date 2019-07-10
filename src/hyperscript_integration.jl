
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

@tags div input font
@tags_noescape style script

# default turn attributes into strings
attribute_render(session, parent, attribute, x) = string(x)
function attribute_render(session, parent, attribute, obs::Observable)
    onjs(session, obs, js"""
    function (value){
        var node = $(parent)
        if(node){
            if(node[$attribute] != value){
                node[$attribute] = value
            }
            return true
        }else{
            return false //deregister
        }
    }
    """)
    return attribute_render(session, parent, attribute, obs[])
end

function attribute_render(session, parent, attribute, jss::JSCode)
    return tojsstring(jss)
end

render_node(session::Session, x) = x

function render_node(session::Session, node::Node)
    # give each node a unique id inside the dom
    node_id = get_unique_dom_id()
    # pretty hacky, but this is the only way I can think of right now
    # to make sure that we always have a unique id for a node
    get!(Hyperscript.attrs(node), "data-jscall-id", node_id)
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
        error("Node $(node) doesn't have a unique id. Call jsrender(session, node) first!")
    end
end

# Handle interpolating into Javascript
function tojsstring(io::IO, node::Node)
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

jsrender(::Session, x::String) = x
jsrender(::Session, x::Hyperscript.Styled) = x
