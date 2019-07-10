
function walk_dom(f, session::Session, x::JSCode, visited = IdDict())
    walk_dom(f, session, x.source, visited)
end

walk_dom(f, session::Session, x, visited = IdDict()) = f(x)

function walk_dom(f, session::Session, x::Union{Tuple, AbstractVector, Pair}, visited = IdDict()) where T
    get!(visited, x, nothing) !== nothing && return
    for elem in x
        walk_dom(f, session, elem, visited)
    end
end

function walk_dom(f, session::Session, x::Node, visited = IdDict())
    get!(visited, x, nothing) !== nothing && return
    for elem in children(x)
        walk_dom(f, session, elem, visited)
    end
    for (name, elem) in Hyperscript.attrs(x)
        walk_dom(f, session, elem, visited)
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
