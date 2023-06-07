
function jsrender(session::Session, md::Markdown.MD)
    md_div = DOM.div(md_html(session, md.content)...; class="markdown-body")
    return jsrender(session, md_div)
end

function md_html(session::Session, content::Vector)
    return md_html.((session,), content)
end

function md_html(session::Session, header::Markdown.Header{l}) where l
    title = header.text
    id = length(title) == 1 && title[1] isa String ? title[1] : ""
    return [DOM.m("h$l", htmlinline(session, header.text)...; id=id)]
end

function md_html(session::Session, code::Markdown.Code)
    maybe_lang = !isempty(code.language) ? Any[:class=>"language-$(code.language)"] : []
    return [DOM.m("pre", DOM.m("code", code.code; maybe_lang...))]
end

function md_html(session::Session, md::Markdown.Paragraph)
    return [DOM.p(htmlinline(session, md.content)...)]
end

function md_html(session::Session, md::Markdown.BlockQuote)
    return [DOM.m("blockquote", md_html(session, md.content)...)]
end

function md_html(session::Session, f::Markdown.Footnote)
    return [DOM.div(DOM.p(f.id; class="footnote-title"), md_html(session, f.text)...;
                          class="footnote", id="footnote-$(f.id)")]
end

function md_html(session::Session, md::Markdown.Admonition)
    title = DOM.p(md.title; class="admonition-title")
    return [DOM.div(title; class="admonition $(md.category)")]
end

function md_html(session::Session, md::Markdown.List)
    maybe_attr = md.ordered > 1 ? Any[:start => string(md.ordered)] : []
    tag = Markdown.isordered(md) ? "ol" : "ul"
    return [DOM.m(
        tag, maybe_attr...,
        map(md.items) do item
            DOM.m("li", md_html(session, item)...)
        end...
        ; style="list-style-type: disc; list-style: inside;")]
end

function md_html(session::Session, md::Markdown.HorizontalRule)
    return [DOM.m_unesc("hr")]
end

function md_html(session::Session, md::Markdown.Table)
    content = map(enumerate(md.rows)) do (i, row)
        tr_content = map(enumerate(md.rows[i])) do (j, c)
            alignment = md.align[j]
            alignment = alignment === :l ? "left" : alignment === :r ? "right" : "center"
            return DOM.m(i == 1 ? "th" : "td", htmlinline(session, c)...; align=alignment)
        end
        return DOM.m("tr", tr_content...)
    end
    return [DOM.m("table", content...)]
end

function htmlinline(session::Session, content::Vector)
    return [htmlinline.((session,), content)...]
end

function htmlinline(session::Session, code::Markdown.Code)
    return [DOM.m("code", code.code)]
end

function htmlinline(session::Session, md::Union{Symbol, AbstractString})
    return [md]
end

function htmlinline(session::Session, md::Markdown.Bold)
    return [DOM.m("strong", htmlinline(session, md.text)...)]
end

function htmlinline(session::Session, md::Markdown.Italic)
    return [DOM.m("em", htmlinline(session, md.text)...)]
end

function htmlinline(session::Session, md::Markdown.Image)
    return [DOM.m("img"; src=md.url, alt=md.alt)]
end

function htmlinline(session::Session, f::Markdown.Footnote)
    return [DOM.m("a", string("[", f.id, "]"); href="#footnote-$(f.id)", class="footnote")]
end

function htmlinline(session::Session, link::Markdown.Link)
    return [DOM.m("a", href = link.url, htmlinline(session, link.text)...)]
end

function htmlinline(session::Session, br::Markdown.LineBreak)
    return [DOM.m("br")]
end

htmlinline(session::Session, x) = [jsrender(session, x)]
md_html(session::Session, x) = [jsrender(session, x)]

function render_result(result)
    if Tables.istable(result)
        return Table(result)
    else
        return DOM.span(result)
    end
end

"""
    replace_expressions(markdown, context)
Replaces all expressions inside `markdown` savely, by only supporting
getindex/getfield expression that will index into `context`
"""
function replace_expressions(session::Session, markdown; eval_julia_code=false)
    if markdown isa Union{Expr, Symbol}
        return markdown
    end
    if hasproperty(markdown, :content)
        markdown.content .= replace_expressions.((session,), markdown.content; eval_julia_code=eval_julia_code)
    elseif hasproperty(markdown, :text)
        markdown.text .= replace_expressions.((session,), markdown.text; eval_julia_code=eval_julia_code)
    end
    return markdown
end

function parseall(str)
    pos = firstindex(str)
    exs = []
    while pos <= lastindex(str)
        ex, pos = Meta.parse(str, pos)
        push!(exs, ex)
    end
    if length(exs) == 0
        throw(Base.ParseError("end of input"))
    elseif length(exs) == 1
        return exs[1]
    else
        return Expr(:block, exs...)
    end
end

function replace_expressions(session::Session, markdown::Markdown.Code; eval_julia_code=false)
    if markdown.language == "julia" && eval_julia_code isa Module
        hide = occursin("# hide", markdown.code)
        no_eval = occursin("# no-eval", markdown.code)
        md_expr = hide ? "" : markdown
        expr = parseall(markdown.code)
        evaled = no_eval ? nothing : eval_julia_code.eval(expr)
        if !isnothing(evaled)
            return Markdown.MD([md_expr, jsrender(session, evaled)])
        else
            return md_expr
        end
    else
        return markdown
    end
end

"""
    string_to_markdown(session::Session, source::String; eval_julia_code=false)

Replaces all interpolation expressions inside `markdown` savely, by only supporting
getindex/getfield expression that will index into `context`.
You can eval Julia code blocks by setting `eval_julia_code` to a Module, into which
the code gets evaluated!
"""
function string_to_markdown(session::Session, source::String; eval_julia_code=false)
    markdown = Markdown.parse(source)
    return replace_expressions(session, markdown; eval_julia_code=eval_julia_code)
end
