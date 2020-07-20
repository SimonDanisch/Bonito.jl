
function walk_dom(f, x::JSCode, visited = IdDict())
    walk_dom(f, x.source, visited)
end

walk_dom(f, x, visited = IdDict()) = f(x)

function walk_dom(f, x::Union{Tuple, AbstractVector, Pair}, visited = IdDict()) where T
    get!(visited, x, nothing) !== nothing && return
    for elem in x
        walk_dom(f, elem, visited)
    end
end

function walk_dom(f, x::Node, visited = IdDict())
    get!(visited, x, nothing) !== nothing && return
    for elem in children(x)
        walk_dom(f, elem, visited)
    end
    for (name, elem) in Hyperscript.attrs(x)
        walk_dom(f, elem, visited)
    end
end

const mime_order = MIME.((
    "text/html", "text/latex", "image/svg+xml", "image/png",
    "image/jpeg", "text/markdown", "application/javascript", "text/plain"
))

function richest_mime(val)
    for mimetype in mime_order
        showable(mimetype, val) && return mimetype
    end
    error("value not writable for any mimetypes")
end

repr_richest(x) = repr(richest_mime(x), x)
repr_richest(x::String) = x
