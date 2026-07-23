
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
md_html(session::Session, x) = [jsrender(session, x)]

function render_result(result)
    if Tables.istable(result)
        return Table(result)
    else
        return DOM.span(result)
    end
end

"""
    contextual_eval(parent, expr)
"Evals" expression without eval by only allowing getfield + getindex expressions

```
contextual_eval(context, :(lala.blalba)) == context.lala.blabla
contextual_eval(context, :(lala.blalba[1])) == context.lala.blabla[1]
contextual_eval(context, :(julia_func())) == error
```
"""
function contextual_eval(parent, expr)
    if expr isa Symbol
        return getfield(parent, expr)
    else
        if expr.head == :(.)
            return getfield(contextual_eval(parent, expr.args[1]), expr.args[2].value)
        elseif expr.head == :ref
            getindex(contextual_eval(parent, expr.args[1]), expr.args[2])
        else
            return contextual_eval(parent, expr.args[1])
        end
    end
end

"""
    replace_expressions(markdown, context)
Replaces all expressions inside `markdown` savely, by only supporting
getindex/getfield expression that will index into `context`
"""
function replace_expressions(markdown, context; eval_julia_code=false)
    if markdown isa Union{Expr, Symbol}
        result = contextual_eval(context, markdown)
        return render_result(result)
    end
    if hasproperty(markdown, :content)
        markdown.content .= replace_expressions.(markdown.content, (context,); eval_julia_code=eval_julia_code)
    elseif hasproperty(markdown, :text)
        markdown.text .= replace_expressions.(markdown.text, (context,); eval_julia_code=eval_julia_code)
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

function replace_interpolation!(context, expr)
    return expr
end

function replace_interpolation!(context, expr::Expr)
    if expr.head == :$
        return contextual_eval(context, expr.args[1])
    else
        expr.args .= replace_interpolation!.((context,), expr.args)
        return expr
    end
end

function replace_expressions(markdown::Markdown.Code, context; eval_julia_code=false)
    if markdown.language == "julia" && eval_julia_code isa Module
        run = Button(">")
        result = Observable{Any}(DOM.span(""))
        on(run) do click
            expr = parseall(markdown.code)
            expr = replace_interpolation!(context, expr)
            evaled = eval_julia_code.eval(expr)
            result[] = render_result(evaled)
        end
        return md"""
        $(markdown)
        $(run)
        $(result)
        """
    else
        return markdown
    end
end

"""
    string_to_markdown(source::String, context; eval_julia_code=false)

Replaces all interpolation expressions inside `markdown` savely, by only supporting
getindex/getfield expression that will index into `context`.
You can eval Julia code blocks by setting `eval_julia_code` to a Module, into which
the code gets evaluated!
"""
function string_to_markdown(source::String, context; eval_julia_code=false)
    markdown = Markdown.parse(source)
    return replace_expressions(markdown, context; eval_julia_code=eval_julia_code)
end
