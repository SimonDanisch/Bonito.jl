abstract type RunnerLike end

struct NoRunner <: RunnerLike end

struct ModuleRunner <: RunnerLike
    mod::Module
    current_session::Ref{Union{Session,Nothing}}
end
ModuleRunner(mod::Module) = ModuleRunner(mod, Ref{Union{Session,Nothing}}(nothing))

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
    if hasproperty(runner, :counter)
        runner.counter = 0 # reset counter if any present
    end
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
    if code.language == "latex"
        return [KaTeX(code.code)]
    end
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
    style = Styles("list-style-type" => "disc")
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
    file, ext = splitext(md.url)
    if ext in (".mp4", ".webm", ".ogg")
        return [DOM.m("video", DOM.m("source"; src=md.url, type="video/$(ext[2:end])"), autoplay=true, controls=true)]
    end
    return [DOM.m("img"; src=md.url, alt=md.alt)]
end

function htmlinline(f::Markdown.Footnote)
    return [DOM.m("a", string("[", f.id, "]"); href="#footnote-$(f.id)", class="footnote")]
end

function htmlinline(link::Markdown.Link)
    return [DOM.m("a", href = link.url, htmlinline(link.text)...)]
end

function htmlinline(latex::Markdown.LaTeX)
    return [KaTeX(latex.formula)]
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
function replace_expressions(markdown::MT, replacements::Dict, runner::RunnerLike) where {MT}
    if haskey(replacements, MT)
        return replacements[MT](markdown)
    end
    if markdown isa Union{Expr, Symbol}
        return markdown
    end
    if hasproperty(markdown, :content)
        markdown.content .= replace_expressions.(markdown.content, (replacements,), (runner,))
    elseif hasproperty(markdown, :text)
        markdown.text .= replace_expressions.(markdown.text, (replacements,), (runner,))
    elseif hasproperty(markdown, :rows)
        # Those are some deeply nested rows!
        map!(markdown.rows, markdown.rows) do row
            map(r-> replace_expressions.(r, (replacements,), (runner,)), row)
        end
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
        if no_eval
            markdown.code = replace(markdown.code, "# no-eval" => "")
            evaled = nothing
        else
            expr = parseall(markdown.code)
            evaled = Base.eval(runner, expr)
        end
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
    # Check if any replacement keys are CommonMark types — if so, use CommonMark parser
    has_cm_keys = any(k -> k isa Type && k <: Union{CommonMark.AbstractBlock, CommonMark.AbstractInline, CommonMark.AbstractContainer}, keys(replacements))
    if has_cm_keys
        ast = bonito_parser(source)
        return commonmark_to_dom(ast; replacements=replacements)
    end
    markdown = Markdown.parse(source)
    return replace_expressions(markdown, replacements, runner)
end

# ============================================================================
# CommonMark.jl Integration
# ============================================================================

"""
    bonito_parser(; kwargs...)

Create a CommonMark parser with all extensions enabled (math, tables,
admonitions, footnotes, strikethrough, raw HTML).

    bonito_parser(source::String; kwargs...)

Parse a markdown string with the full-featured parser.
"""
function bonito_parser(; kwargs...)
    parser = CommonMark.Parser(; kwargs...)
    CommonMark.enable!(parser, CommonMark.DollarMathRule())
    CommonMark.enable!(parser, CommonMark.TableRule())
    CommonMark.enable!(parser, CommonMark.AdmonitionRule())
    CommonMark.enable!(parser, CommonMark.FootnoteRule())
    CommonMark.enable!(parser, CommonMark.StrikethroughRule())
    CommonMark.enable!(parser, CommonMark.RawContentRule())
    CommonMark.enable!(parser, CommonMark.AttributeRule())
    return parser
end

function bonito_parser(source::String; kwargs...)
    parser = bonito_parser(; kwargs...)
    return parser(source)
end

"""
    CommonMarkDOM

Wrapper around a DOM element produced by `commonmark_to_dom`.
This is returned by `string_to_markdown` when CommonMark replacements
are used, and `jsrender` dispatches on it to render the DOM.
"""
struct CommonMarkDOM
    dom::Any
end

function jsrender(session::Session, cmd::CommonMarkDOM)
    return jsrender(session, cmd.dom)
end

"""
    commonmark_to_dom(ast::CommonMark.Node; replacements=Dict())

Walk a CommonMark AST and produce Bonito DOM elements.

Uses a stack-based approach:
- On entering a container node: push a new children collector
- On exiting a container node: pop children, create DOM element, push to parent
- For leaf nodes: create element immediately, push to current collector

`replacements` is a `Dict{Type, Function}` mapping CommonMark node types
(e.g. `CommonMark.CodeBlock`, `CommonMark.Image`) to functions that receive
the `CommonMark.Node` and return either a DOM element or `nothing` (to use default).
"""
function commonmark_to_dom(ast::CommonMark.Node; replacements=Dict{Any,Function}())
    # Stack of children collectors. Each entry is a (node_type, children) pair.
    stack = Tuple{Any, Vector{Any}}[(nothing, Any[])]

    for (node, entering) in ast
        t = node.t
        T = typeof(t)

        # Check for replacement
        if haskey(replacements, T)
            result = replacements[T](node)
            if result !== nothing
                # Non-container replacement: push result directly
                if !entering || !CommonMark.is_container(t)
                    push!(last(stack)[2], result)
                    continue
                end
                # For container replacements that returned something,
                # we still push it as a leaf (skip children)
                push!(last(stack)[2], result)
                continue
            end
            # result === nothing means "use default rendering"
        end

        if CommonMark.is_container(t)
            if entering
                push!(stack, (t, Any[]))
            else
                # Pop children and create element
                (node_type, children_vec) = pop!(stack)
                element = make_dom_element(node_type, node, children_vec)
                push!(last(stack)[2], element)
            end
        else
            # Leaf node — create element immediately
            element = make_dom_leaf(t, node)
            push!(last(stack)[2], element)
        end
    end

    # The root Document's children are in the last stack entry
    (_, root_children) = pop!(stack)
    return CommonMarkDOM(DOM.div(root_children...; class="markdown-body"))
end

# ============================================================================
# Container node → DOM element
# ============================================================================

function make_dom_element(t::CommonMark.Document, node, children)
    # Document is the root — just return children as-is for the wrapper
    return children
end

function make_dom_element(t::CommonMark.Heading, node, children)
    level = t.level
    id = length(children) == 1 && children[1] isa String ? children[1] : ""
    return DOM.m("h$level", children...; id=id)
end

function make_dom_element(t::CommonMark.Paragraph, node, children)
    return DOM.p(children...)
end

function make_dom_element(t::CommonMark.Strong, node, children)
    return DOM.m("strong", children...)
end

function make_dom_element(t::CommonMark.Emph, node, children)
    return DOM.m("em", children...)
end

function make_dom_element(t::CommonMark.Link, node, children)
    return DOM.m("a", children...; href=t.destination)
end

function make_dom_element(t::CommonMark.Image, node, children)
    alt_text = join(filter(c -> c isa String, children), "")
    dest = t.destination
    _, ext = splitext(dest)
    if ext in (".mp4", ".webm", ".ogg")
        return DOM.m("video", DOM.m("source"; src=dest, type="video/$(ext[2:end])"); autoplay=true, controls=true)
    end
    return DOM.m("img"; src=dest, alt=alt_text)
end

function make_dom_element(t::CommonMark.List, node, children)
    ld = t.list_data
    if ld.type === :ordered
        if ld.start > 1
            return DOM.m("ol", children...; start=string(ld.start))
        else
            return DOM.m("ol", children...)
        end
    else
        return DOM.m("ul", children...)
    end
end

function make_dom_element(t::CommonMark.Item, node, children)
    return DOM.m("li", children...)
end

function make_dom_element(t::CommonMark.BlockQuote, node, children)
    return DOM.m("blockquote", children...)
end

function make_dom_element(t::CommonMark.Table, node, children)
    return DOM.m("table", children...)
end

function make_dom_element(t::CommonMark.TableHeader, node, children)
    return DOM.m("thead", children...)
end

function make_dom_element(t::CommonMark.TableBody, node, children)
    return DOM.m("tbody", children...)
end

function make_dom_element(t::CommonMark.TableRow, node, children)
    return DOM.m("tr", children...)
end

function make_dom_element(t::CommonMark.TableCell, node, children)
    tag = t.header ? "th" : "td"
    align = t.align === :left ? "left" : t.align === :right ? "right" : t.align === :center ? "center" : ""
    if isempty(align)
        return DOM.m(tag, children...)
    else
        return DOM.m(tag, children...; style="text-align: $align")
    end
end

function make_dom_element(t::CommonMark.Strikethrough, node, children)
    return DOM.m("s", children...)
end

function make_dom_element(t::CommonMark.Admonition, node, children)
    title = DOM.p(t.title; class="admonition-title")
    return DOM.div(title, children...; class="admonition $(t.category)")
end

function make_dom_element(t::CommonMark.FootnoteDefinition, node, children)
    return DOM.div(DOM.p(t.id; class="footnote-title"), children...;
                   class="footnote", id="footnote-$(t.id)")
end

# Fallback for unknown container types
function make_dom_element(t, node, children)
    return DOM.div(children...)
end

# ============================================================================
# Leaf node → DOM element
# ============================================================================

function make_dom_leaf(t::CommonMark.Text, node)
    return node.literal
end

function make_dom_leaf(t::CommonMark.Code, node)
    return DOM.m("code", node.literal)
end

function make_dom_leaf(t::CommonMark.CodeBlock, node)
    info = t.info
    if info == "latex"
        return KaTeX(node.literal)
    end
    maybe_lang = !isempty(info) ? Any[:class => "language-$(info)"] : Any[]
    return DOM.m("pre", DOM.m("code", node.literal; maybe_lang...))
end

function make_dom_leaf(t::CommonMark.Math, node)
    return KaTeX(node.literal; display=t.display)
end

function make_dom_leaf(t::CommonMark.DisplayMath, node)
    return KaTeX(node.literal; display=true)
end

function make_dom_leaf(t::CommonMark.SoftBreak, node)
    return " "
end

function make_dom_leaf(t::CommonMark.LineBreak, node)
    return DOM.m("br")
end

function make_dom_leaf(t::CommonMark.ThematicBreak, node)
    return DOM.m_unesc("hr")
end

function make_dom_leaf(t::CommonMark.HtmlInline, node)
    return DontEscape(node.literal)
end

function make_dom_leaf(t::CommonMark.HtmlBlock, node)
    return DontEscape(node.literal)
end

function make_dom_leaf(t::CommonMark.FootnoteLink, node)
    return DOM.m("a", string("[", t.id, "]"); href="#footnote-$(t.id)", class="footnote")
end

# Fallback for unknown leaf types
function make_dom_leaf(t, node)
    lit = node.literal
    return isempty(lit) ? "" : lit
end
