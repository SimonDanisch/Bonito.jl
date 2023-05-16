
struct Break end

function walk_dom(f, x::JSCode, visited = IdDict())
    f(x)
    walk_dom(f, x.source, visited)
end

walk_dom(f, x, visited = IdDict()) = f(x)

walk_dom(f, x::Markdown.MD, visited = IdDict()) = walk_dom(f, x.content, visited)
walk_dom(f, x::Markdown.Header, visited = IdDict()) = walk_dom(f, x.text, visited)
walk_dom(f, x::Markdown.Paragraph, visited = IdDict()) = walk_dom(f, x.content, visited)

function walk_dom(f, x::Union{Tuple, AbstractVector, Pair}, visited = IdDict())
    get!(visited, x, nothing) !== nothing && return
    for elem in x
        f(elem)
        res = walk_dom(f, elem, visited)
        res isa Break && return res
    end
end

function walk_dom(f, x::Node, visited = IdDict())
    get!(visited, x, nothing) !== nothing && return
    for elem in children(x)
        f(elem)
        res = walk_dom(f, elem, visited)
        res isa Break && return res
    end
    for (name, elem) in Hyperscript.attrs(x)
        f(elem)
        res = walk_dom(f, elem, visited)
        res isa Break && return res
    end
end

function find_head_body(dom::Node)
    head = nothing
    body = nothing
    walk_dom(dom) do x
        !(x isa Node) && return
        t = Hyperscript.tag(x)
        if t == "body"
            body = x
        elseif t == "head"
            head = x
        end
        # if we found head & body, we can exit!
        !isnothing(body) && !isnothing(head) && return Break()
    end

    return head, body, dom
end

const mime_order = MIME.((
    "text/html", "text/latex", "image/svg+xml", "image/png",
    "image/jpeg", "text/markdown", "application/javascript", "text/plain"
))

function richest_mime(val)
    for mimetype in mime_order
        showable(mimetype, val) && return mimetype
    end
    error("value with type $(typeof(val)) not writable for any mimetypes")
end

mime_string(::MIME{T}) where {T} = string(T)


function wait_for(condition; timeout=10)
    tstart = time()
    while true
        condition() && return :success
        (time() - tstart > timeout) && return :timed_out
        yield()
    end
    return
end
