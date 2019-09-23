function jsrender(session::Session, content::Vector)
    DOM.um("span", jsrender.((session,), content)...)
end

jsrender(session::Session, md::Markdown.MD) = JSServe.jsrender(session, jsrender(session, md.content))

function jsrender(session::Session, header::Markdown.Header{l}) where l
    DOM.um("h$l", htmlinline(session, header.text))
end

function jsrender(session::Session, code::Markdown.Code)
    maybe_lang = !isempty(code.language) ? Any[:class=>"language-$(code.language)"] : []
    DOM.um("pre", DOM.um("code", maybe_lang..., code.code))
end

function jsrender(session::Session, md::Markdown.Paragraph)
    return DOM.p(htmlinline(session, md.content))
end

function jsrender(session::Session, md::Markdown.BlockQuote)
    DOM.um("blockquote", jsrender(session, md.content))
end

function jsrender(session::Session, f::Markdown.Footnote)
    return DOM.div(
        class = "footnote", id = "footnote-$(f.id)",
        DOM.p(class = "footnote-title", f.id),
        jsrender(session, f.text)
    )
end

function jsrender(session::Session, md::Markdown.Admonition)
    return DOM.div(class = "admonition $(md.category)") do
        DOM.p(class = "admonition-title", md.title)
        jsrender(session, md.content)
    end
end

function jsrender(session::Session, md::Markdown.List)
    maybe_attr = md.ordered > 1 ? Any[:start => string(md.ordered)] : []
    tag = Markdown.isordered(md) ? "ol" : "ul"
    DOM.um(
        tag, maybe_attr...,
        map(md.items) do item
            DOM.um("li", jsrender(session, item))
        end...
    )
end

function jsrender(session::Session, md::Markdown.HorizontalRule)
    return DOM.m_unesc("hr")
end


function htmlinline(session::Session, content::Vector)
    DOM.um("div", htmlinline.((session,), content)...)
end

function htmlinline(session::Session, code::Markdown.Code)
    DOM.um("code", code.code)
end

function htmlinline(session::Session, md::Union{Symbol, AbstractString})
    return md
end

function htmlinline(session::Session, md::Markdown.Bold)
    DOM.um("strong", htmlinline(session, md.text))
end

function htmlinline(session::Session, md::Markdown.Italic)
    DOM.um("em", htmlinline(session, md.text))
end

function htmlinline(session::Session, md::Markdown.Image)
    DOM.um("img", src = md.url, alt = md.alt)
end


function htmlinline(session::Session, f::Markdown.Footnote)
    DOM.um("a", href = "#footnote-$(f.id)", class = "footnote", string(session, "[", f.id, "]"))
end

function htmlinline(session::Session, link::Markdown.Link)
    return DOM.um("a", href = link.url, htmlinline(session, link.text))
end

function htmlinline(session::Session, br::Markdown.LineBreak)
    DOM.um("br")
end

htmlinline(session::Session, x) = jsrender(session, x)
