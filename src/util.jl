
function walk_dom(f, x::JSCode, visited = IdDict())
    walk_dom(f, x.source, visited)
end

walk_dom(f, x, visited = IdDict()) = f(x)

walk_dom(f, x::Markdown.MD, visited = IdDict()) = walk_dom(f, x.content, visited)
walk_dom(f, x::Markdown.Header, visited = IdDict()) = walk_dom(f, x.text, visited)
walk_dom(f, x::Markdown.Paragraph, visited = IdDict()) = walk_dom(f, x.content, visited)

function walk_dom(f, x::Union{Tuple, AbstractVector, Pair}, visited = IdDict())
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
repr_richest(x::Number) = sprint(print, x)

columns(args...; class="") = DOM.div(args..., class=class * " flex flex-col")
rows(args...; class="") = DOM.div(args..., class=class * " flex flex-row")

function grid(args...; cols=4, rows=4, class="")
    class *= " grid auto-cols-max grid-cols-$(cols) grid-rows-$(rows) gap-4"
    return DOM.div(args..., class=class)
end

function styled_slider(slider, value; class="")
    return rows(slider,
                DOM.span(value, class="p-1");
                class="w-64 p-2 items-center " * class)
end
