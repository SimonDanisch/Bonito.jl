abstract type RunnerLike end

struct NoRunner <: RunnerLike end

struct ModuleRunner <: RunnerLike
    mod::Module
    current_session::Ref{Union{Session,Nothing}}
end

function Base.eval(md::ModuleRunner, expr)
    return md.mod.eval(md.mod, expr)
end

struct EvalMarkdown
    markdown::String
    runner::RunnerLike
    replacements::Dict{Any,Function}
end

function EvalMarkdown(
        markdown::String; runner=NoRunner(), replacements=Dict{Any,Function}()
    )
    return EvalMarkdown(markdown, runner, replacements)
end

function jsrender(session::Session, em::EvalMarkdown)
    runner = em.runner
    if hasproperty(runner, :current_session)
        runner.current_session[] = session
    end
    md = string_to_markdown(em.markdown, em.replacements; eval_julia_code=runner)
    return jsrender(session, md)
end

function jsrender(session::Session, md::Markdown.MD)
    md_div = DOM.div(md_html(md.content)...; class="markdown-body")
    return jsrender(session, md_div)
end

function md_html(content::Vector)
    return map(md_html, content)
end

function md_html(header::Markdown.Header{l}) where l
    title = header.text
    id = length(title) == 1 && title[1] isa String ? title[1] : ""
    return [DOM.m("h$l", htmlinline(header.text)...; id=id)]
end

function md_html(code::Markdown.Code)
    maybe_lang = !isempty(code.language) ? Any[:class=>"language-$(code.language)"] : []
    return [DOM.m("pre", DOM.m("code", code.code; maybe_lang...))]
end

function md_html(md::Markdown.Paragraph)
    return [DOM.p(htmlinline(md.content)...)]
end

function md_html(md::Markdown.BlockQuote)
    return [DOM.m("blockquote", md_html(md.content)...)]
end

function md_html(f::Markdown.Footnote)
    return [DOM.div(DOM.p(f.id; class="footnote-title"), md_html(f.text)...;
                          class="footnote", id="footnote-$(f.id)")]
end

function md_html(md::Markdown.Admonition)
    title = DOM.p(md.title; class="admonition-title")
    return [DOM.div(title; class="admonition $(md.category)")]
end

function md_html(md::Markdown.List)
    maybe_attr = md.ordered > 1 ? Any[:start => string(md.ordered)] : []
    tag = Markdown.isordered(md) ? "ol" : "ul"
    style = Styles("list-style-type" => "disc", "list-style" => "inside")
    return [DOM.m(
        tag, maybe_attr...,
        map(md.items) do item
            DOM.m("li", md_html(item)...)
        end...
        ; style=style)]
end

function md_html(md::Markdown.HorizontalRule)
    return [DOM.m_unesc("hr")]
end

function md_html(md::Markdown.Table)
    content = map(enumerate(md.rows)) do (i, row)
        tr_content = map(enumerate(md.rows[i])) do (j, c)
            alignment = md.align[j]
            alignment = alignment === :l ? "left" : alignment === :r ? "right" : "center"
            return DOM.m(i == 1 ? "th" : "td", htmlinline(c)...; align=alignment)
        end
        return DOM.m("tr", tr_content...)
    end
    return [DOM.m("table", content...)]
end

function htmlinline(content::Vector)
    return [htmlinline.(content)...]
end

function htmlinline(code::Markdown.Code)
    return [DOM.m("code", code.code)]
end

function htmlinline(md::Union{Symbol, AbstractString})
    return [md]
end

function htmlinline(md::Markdown.Bold)
    return [DOM.m("strong", htmlinline(md.text)...)]
end

function htmlinline(md::Markdown.Italic)
    return [DOM.m("em", htmlinline(md.text)...)]
end

function htmlinline(md::Markdown.Image)
    return [DOM.m("img"; src=md.url, alt=md.alt)]
end

function htmlinline(f::Markdown.Footnote)
    return [DOM.m("a", string("[", f.id, "]"); href="#footnote-$(f.id)", class="footnote")]
end

function htmlinline(link::Markdown.Link)
    return [DOM.m("a", href = link.url, htmlinline(link.text)...)]
end

function htmlinline(br::Markdown.LineBreak)
    return [DOM.m("br")]
end

htmlinline(x) = [x]
md_html(x) = [x]

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
function replace_expressions(markdown, replacements::Dict, runner::RunnerLike)
    if markdown isa Union{Expr, Symbol}
        return markdown
    end
    if hasproperty(markdown, :content)
        markdown.content .= replace_expressions.(markdown.content, (replacements,), (runner,))
    elseif hasproperty(markdown, :text)
        markdown.text .= replace_expressions.(markdown.text, (replacements,), (runner,))
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



function replace_expressions(
        markdown::Markdown.Code, replacements::Dict, runner::RunnerLike
    )
    if haskey(replacements, Markdown.Code)
        return replacements[Markdown.Code](markdown)
    end
    if markdown.language == "julia" && !(runner isa NoRunner)
        hide = occursin("# hide", markdown.code)
        no_eval = occursin("# no-eval", markdown.code)
        md_expr = hide ? "" : markdown
        expr = parseall(markdown.code)
        evaled = no_eval ? nothing : Base.eval(runner, expr)
        if !isnothing(evaled)
            return Markdown.MD([md_expr, evaled])
        else
            return md_expr
        end
    else
        return markdown
    end
end

"""
    string_to_markdown(source::String; eval_julia_code=false)

Replaces all interpolation expressions inside `markdown` savely, by only supporting
getindex/getfield expression that will index into `context`.
You can eval Julia code blocks by setting `eval_julia_code` to a Module, into which
the code gets evaluated!
"""
function string_to_markdown(source::String, replacements=Dict{Any, Function}(); eval_julia_code=NoRunner())
    if eval_julia_code == false
        runner = NoRunner()
    elseif eval_julia_code isa Module
        runner = ModuleRunner(eval_julia_code)
    elseif eval_julia_code isa RunnerLike
        runner = eval_julia_code
    else
        error("Unsupported type for `eval_julia_code`: $(eval_julia_code). Supported are `false`, a Module to eval in, or a `Bonito.RunnerLike`.")
    end
    markdown = Markdown.parse(source)
    return replace_expressions(markdown, replacements, runner)
end
