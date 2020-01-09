
function jsrender(session::Session, md::Markdown.MD)
    md_div = DOM.div(md_html(session, md.content)...; class="markdown-body")
    return JSServe.jsrender(session, md_div)
end

function md_html(session::Session, content::Vector)
    return md_html.((session,), content)
end

function md_html(session::Session, header::Markdown.Header{l}) where l
    return [DOM.um("h$l", htmlinline(session, header.text)...)]
end

function md_html(session::Session, code::Markdown.Code)
    maybe_lang = !isempty(code.language) ? Any[:class=>"language-$(code.language)"] : []
    return [DOM.um("pre", DOM.um("code", code.code; maybe_lang...))]
end

function md_html(session::Session, md::Markdown.Paragraph)
    return [DOM.p(htmlinline(session, md.content)...)]
end

function md_html(session::Session, md::Markdown.BlockQuote)
    return [DOM.um("blockquote", md_html(session, md.content)...)]
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
    return [DOM.um(
        tag, maybe_attr...,
        map(md.items) do item
            DOM.um("li", md_html(session, item)...)
        end...
    )]
end

function md_html(session::Session, md::Markdown.HorizontalRule)
    return [DOM.m_unesc("hr")]
end

function md_html(session::Session, md::Markdown.Table)
    content = map(enumerate(md.rows)) do (i, row)
        tr_content = map(enumerate(md.rows[i])) do (j, c)
            alignment = md.align[j]
            alignment = alignment === :l ? "left" : alignment === :r ? "right" : "center"
            return DOM.um(i == 1 ? "th" : "td", htmlinline(session, c)...; align=alignment)
        end
        return DOM.um("tr", tr_content...)
    end
    return [DOM.um("table", content...)]
end

function htmlinline(session::Session, content::Vector)
    return htmlinline.((session,), content)
end

function htmlinline(session::Session, code::Markdown.Code)
    return [DOM.um("code", code.code)]
end

function htmlinline(session::Session, md::Union{Symbol, AbstractString})
    return [md]
end

function htmlinline(session::Session, md::Markdown.Bold)
    return [DOM.um("strong", htmlinline(session, md.text)...)]
end

function htmlinline(session::Session, md::Markdown.Italic)
    return [DOM.um("em", htmlinline(session, md.text)...)]
end

function htmlinline(session::Session, md::Markdown.Image)
    return [DOM.um("img"; src=md.url, alt=md.alt)]
end

function htmlinline(session::Session, f::Markdown.Footnote)
    return [DOM.um("a", string("[", f.id, "]"); href="#footnote-$(f.id)", class="footnote")]
end

function htmlinline(session::Session, link::Markdown.Link)
    return [DOM.um("a", href = link.url, htmlinline(session, link.text)...)]
end

function htmlinline(session::Session, br::Markdown.LineBreak)
    return [DOM.um("br")]
end

htmlinline(session::Session, x) = [jsrender(session, x)]
