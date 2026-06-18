# Convert a Documenter MarkdownAST tree into Bonito DOM.
#
# Mirrors the node dispatch of DocumenterVitepress' writer.jl, but instead of
# emitting markdown strings we build Bonito `DOM` nodes that get exported to a
# static, VitePress-styled site.

"""
    DCtx(doc, page, settings, builddir)

Render context threaded through every `domify` call so node renderers can resolve
cross-references, write image files and read the writer settings.
"""
struct DCtx
    doc::Any
    page::Any
    settings::Any
    builddir::String
end

# ---- entry points ----------------------------------------------------------

domify(ctx::DCtx, node::MA.Node) = domify(ctx, node, node.element)

"""Render all children of `node`, flattening vector results into one list."""
function domify_children(ctx::DCtx, node::MA.Node)
    out = Any[]
    for child in node.children
        r = domify(ctx, child)
        if r isa AbstractVector
            append!(out, r)
        elseif r === nothing
            # skip
        else
            push!(out, r)
        end
    end
    return out
end

# ---- inline elements -------------------------------------------------------

domify(::DCtx, ::MA.Node, text::MA.Text) = text.text
domify(::DCtx, ::MA.Node, ::MA.LineBreak) = DOM.br()
domify(::DCtx, ::MA.Node, ::MA.SoftBreak) = " "
domify(::DCtx, ::MA.Node, c::MA.Code) = DOM.code(c.code)

domify(ctx::DCtx, node::MA.Node, ::MA.Strong) = DOM.strong(domify_children(ctx, node)...)
domify(ctx::DCtx, node::MA.Node, ::MA.Emph) = DOM.em(domify_children(ctx, node)...)

function domify(ctx::DCtx, node::MA.Node, link::MA.Link)
    DOM.a(domify_children(ctx, node)...; href = link.destination, title = link.title)
end

domify(::DCtx, ::MA.Node, html::MA.HTMLInline) = DOM.m_unesc("span", html.html; style = "display:contents")

domify(::DCtx, ::MA.Node, math::MA.InlineMath) = DOM.span("\\(" * math.math * "\\)")

# ---- block elements --------------------------------------------------------

domify(ctx::DCtx, node::MA.Node, ::MA.Paragraph) = DOM.p(domify_children(ctx, node)...)
domify(::DCtx, ::MA.Node, ::MA.ThematicBreak) = DOM.hr()
domify(ctx::DCtx, node::MA.Node, ::MA.BlockQuote) = DOM.blockquote(domify_children(ctx, node)...)
domify(::DCtx, ::MA.Node, math::MA.DisplayMath) = DOM.div("\\[" * math.math * "\\]")

function domify(ctx::DCtx, node::MA.Node, list::MA.List)
    items = map(node.children) do item
        DOM.li(domify_children(ctx, item)...)
    end
    tag = list.type === :ordered ? DOM.ol : DOM.ul
    return tag(items...)
end

# Headings without an anchor (e.g. inside docstrings)
function domify(ctx::DCtx, node::MA.Node, heading::MA.Heading)
    tag = getfield(DOM, Symbol("h", heading.level))
    return tag(domify_children(ctx, node)...)
end

# Anchored headings carry an id + a clickable anchor link.
function domify(ctx::DCtx, node::MA.Node, header::Documenter.AnchoredHeader)
    anchor = header.anchor
    id = Documenter.anchor_label(anchor)
    heading = first(node.children)
    level = heading.element.level
    tag = getfield(DOM, Symbol("h", level))
    children = domify_children(ctx, heading)
    return tag(
        children...,
        DOM.a("​#"; class = "header-anchor", href = "#" * id, ariaLabel = "Permalink");
        id = id,
    )
end

# ---- code blocks -----------------------------------------------------------

const COPY_SVG = """<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path></svg>"""

copy_button() = DOM.m_unesc("button", COPY_SVG; class = "copy", title = "Copy to clipboard", type = "button")

function highlight_lang(info::AbstractString)
    lang = first(split(info, ' '; limit = 2))
    if lang in ("julia-repl", "@repl", "@example", "@eval", "")
        return "julia"
    elseif lang in ("documenter-ansi", "@ansi", "ansi")
        return "ansi"
    end
    return lang
end

function code_block(lang::AbstractString, code::AbstractString)
    DOM.div(
        DOM.span(lang; class = "lang"),
        copy_button(),
        DOM.pre(DOM.code(code; class = "language-$(lang)"));
        class = "language-$(lang)",
    )
end

function domify(ctx::DCtx, node::MA.Node, code::MA.CodeBlock)
    info = code.info
    # `@…` info strings usually mean an unexpanded directive, but they also occur
    # legitimately for example blocks shown verbatim inside docstrings — so just
    # render as code and note it at debug level rather than warning.
    if startswith(info, "@")
        @debug "BonitoDocumenter: rendering `$(info)` block verbatim on page $(ctx.page.source)."
    end
    return code_block(highlight_lang(info), code.code)
end

# ---- admonitions -----------------------------------------------------------

function admonition_class(category::AbstractString)
    category in ("info", "note", "tip", "warning", "danger", "caution", "important") || return "tip"
    category == "caution" ? "warning" : category
end

function domify(ctx::DCtx, node::MA.Node, adm::MA.Admonition)
    cls = admonition_class(adm.category)
    title = isempty(adm.title) ? uppercasefirst(adm.category) : adm.title
    return DOM.div(
        DOM.p(title; class = "custom-block-title"),
        domify_children(ctx, node)...;
        class = "custom-block $(cls)",
    )
end

# ---- tables ----------------------------------------------------------------

function domify(ctx::DCtx, node::MA.Node, table::MA.Table)
    aligns = map(table.spec) do a
        a === :right ? "right" : a === :center ? "center" : "left"
    end
    head_rows = MA.Node[]
    body_rows = MA.Node[]
    for row in node.children
        if row.element isa MA.TableHeader
            append!(head_rows, collect(row.children))
        elseif row.element isa MA.TableBody
            append!(body_rows, collect(row.children))
        end
    end
    cell(tag, row) = map(enumerate(row.children)) do (j, c)
        align = j <= length(aligns) ? aligns[j] : "left"
        tag(domify_children(ctx, c)...; style = "text-align:$(align)")
    end
    thead = DOM.thead((DOM.tr(cell(DOM.th, r)...) for r in head_rows)...)
    tbody = DOM.tbody((DOM.tr(cell(DOM.td, r)...) for r in body_rows)...)
    return DOM.table(thead, tbody)
end

# ---- images / media --------------------------------------------------------

const VIDEO_EXTENSIONS = (".mp4", ".webm", ".ogg", ".ogv", ".m4v", ".mov", ".mkv")
is_video(path) = any(ext -> endswith(lowercase(String(path)), ext), VIDEO_EXTENSIONS)

function media_node(url::AbstractString, alt)
    if is_video(url)
        return DOM.video(; src = url, controls = true)
    else
        return DOM.img(; src = url, alt = alt)
    end
end

function domify(ctx::DCtx, node::MA.Node, image::MA.Image)
    alt = sprint(io -> print(io, Documenter.MDFlatten.mdflatten(node)))
    return media_node(replace(image.destination, "\\" => "/"), alt)
end

function domify(ctx::DCtx, node::MA.Node, image::Documenter.LocalImage)
    abs_path = joinpath(ctx.builddir, image.path)
    rel = relpath(abs_path, ctx.builddir)
    return media_node(replace(rel, "\\" => "/"), "")
end

# ---- cross references ------------------------------------------------------

# Pages keep their source-relative path but with an `.html` extension.
function html_from_source(src::AbstractString, fragment::AbstractString = "")
    name = splitext(replace(src, "\\" => "/"))[1] * ".html"
    return isempty(fragment) ? name : string(name, "#", fragment)
end

function domify(ctx::DCtx, node::MA.Node, link::Documenter.PageLink)
    src = Documenter.pagekey(ctx.doc, link.page)
    href = html_from_source(src, String(link.fragment))
    return DOM.a(domify_children(ctx, node)...; href = replace(href, " " => "%20"))
end

function domify(ctx::DCtx, node::MA.Node, link::Documenter.LocalLink)
    href = isempty(link.fragment) ? link.path : string(link.path, "#", link.fragment)
    href = replace(href, ".md" => ".html")
    return DOM.a(domify_children(ctx, node)...; href = replace(href, " " => "%20"))
end

# ---- metadata / raw --------------------------------------------------------

domify(::DCtx, ::MA.Node, ::Documenter.MetaNode) = nothing
domify(::DCtx, ::MA.Node, ::Documenter.SetupNode) = nothing

function domify(::DCtx, ::MA.Node, raw::Documenter.RawNode)
    raw.name === :html || return nothing
    return DOM.m_unesc("div", raw.text; style = "display:contents")
end

function domify(ctx::DCtx, node::MA.Node, eval::Documenter.EvalNode)
    eval.result === nothing && return nothing
    return domify(ctx, eval.result)
end

# A bare anonymous AST node (Node{Nothing}) – render its children.
domify(ctx::DCtx, node::MA.Node, ::Nothing) = domify_children(ctx, node)

# ---- @docs / docstrings ----------------------------------------------------

function domify(ctx::DCtx, node::MA.Node, ::Documenter.DocsNodesBlock)
    return domify_children(ctx, node)
end

function domify(ctx::DCtx, node::MA.Node, docs::Documenter.DocsNodes)
    return [domify(ctx, d) for d in docs.docs]
end

function domify(ctx::DCtx, node::MA.Node, docs::Documenter.DocsNode)
    open_attr = get(ctx.page.globals.meta, :CollapsedDocStrings, false) ? Dict() : Dict(:open => true)
    id = Documenter.anchor_label(docs.anchor)
    category = string(Documenter.doccat(docs.object))
    body = Any[]
    for (docast, result) in zip(docs.mdasts, docs.results)
        append!(body, domify_children(ctx, docast))
        url = Documenter.source_url(ctx.doc, result)
        if url !== nothing
            push!(body, DOM.a("source"; class = "VPBadge info source-link", href = url, target = "_blank", rel = "noreferrer"))
        end
    end
    summary = DOM.summary(
        DOM.a(DOM.span(string(docs.object.binding); class = "jlbinding"); id = id, href = "#" * id),
        DOM.span(category; class = "VPBadge info"),
    )
    return DOM.details(summary, DOM.div(body...; class = "docstring-body"); class = "jldocstring custom-block", open_attr...)
end

# ---- index / contents nodes -----------------------------------------------

function domify(ctx::DCtx, node::MA.Node, index::Documenter.IndexNode)
    items = map(index.elements) do (object, _, page, mod, cat)
        DOM.li(DOM.a(DOM.code(string(object.binding)); href = "#" * Documenter.slugify(object)))
    end
    return DOM.ul(items...)
end

function domify(ctx::DCtx, node::MA.Node, contents::Documenter.ContentsNode)
    items = map(contents.elements) do (count, path, anchor)
        href = html_from_source(path, lstrip(Documenter.anchor_fragment(anchor), '#'))
        label = Documenter.MDFlatten.mdflatten(anchor.node)
        DOM.li(DOM.a(label; href = href))
    end
    return DOM.ul(items...)
end

# ---- @example (our expander; holds the live result) ------------------------

function domify(ctx::DCtx, node::MA.Node, ex::BonitoExample)
    out = Any[]
    isempty(ex.input) || push!(out, code_block(highlight_lang(ex.codeblock.info), ex.input))
    rendered = example_result(ctx, node, ex.result)
    rendered === nothing || push!(out, rendered)
    if ex.result === nothing
        s = strip(ex.stdout)
        isempty(s) || push!(out, render_mime(ctx, MIME"text/plain"(), s))
    end
    return out
end

# Drop the live result straight into the page DOM. Apps and anything that renders
# as HTML (Makie figures, etc.) go in as `DOM.div(app)` so they render through the
# page's own session; everything else falls back to Documenter's display dict.
function example_result(ctx::DCtx, node::MA.Node, result)
    result === nothing && return nothing
    if result isa Bonito.App
        return DOM.div(result; class = "bonito-output")
    elseif showable(MIME"text/html"(), result)
        return DOM.div(Bonito.App(() -> result); class = "bonito-output")
    end
    d = Base.invokelatest(Documenter.display_dict, result; context = :color => true)
    return domify(ctx, node, d)
end

# ---- multi output (legacy @repl/@eval path) --------------------------------

function domify(ctx::DCtx, node::MA.Node, ::Documenter.MultiOutput)
    return domify_children(ctx, node)
end

function domify(ctx::DCtx, node::MA.Node, el::Documenter.MultiOutputElement)
    return domify(ctx, node, el.element)
end

function domify(ctx::DCtx, node::MA.Node, mcb::Documenter.MultiCodeBlock)
    blocks = [c.element::MA.CodeBlock for c in node.children]
    code = join((b.code for b in blocks), "\n")
    return code_block(highlight_lang(mcb.language), code)
end

# MIME selection for @example output dicts.
mime_priority(::MIME) = nothing
mime_priority(::MIME"text/plain") = 0.0
mime_priority(::MIME"text/latex") = 0.5
mime_priority(::MIME"text/markdown") = 1.0
mime_priority(::MIME"text/html") = 2.0
mime_priority(::MIME"image/svg+xml") = 3.0
mime_priority(::MIME"image/png") = 4.0
mime_priority(::MIME"image/webp") = 5.0
mime_priority(::MIME"image/gif") = 9.0
mime_priority(::MIME"image/jpeg") = 6.0
mime_priority(::MIME"video/mp4") = 11.0

function domify(ctx::DCtx, node::MA.Node, d::Dict{MIME, Any})
    mimes = filter(m -> mime_priority(m) !== nothing, collect(keys(d)))
    isempty(mimes) && return nothing
    best = last(sort(mimes; by = mime_priority))
    return render_mime(ctx, best, d[best])
end

# Raw text/html output (e.g. from @repl/@eval blocks Documenter still handles).
function render_mime(ctx::DCtx, ::MIME"text/html", html)
    return DOM.m_unesc("div", string(html); class = "bonito-output", style = "display:contents")
end

function render_mime(ctx::DCtx, ::MIME"text/plain", str)
    s = string(str)
    if Bonito.has_ansi_codes(s)
        return DOM.div(Bonito.ANSI_CSS, DOM.m_unesc("div", Bonito.ansi_to_html(s)); class = "ansi-output")
    end
    return DOM.div(s; class = "ansi-output")
end

render_mime(ctx::DCtx, ::MIME"text/markdown", str) = DOM.div(Bonito.string_to_markdown(string(str)))
render_mime(ctx::DCtx, ::MIME"text/latex", str) = DOM.div(string(str))

function write_media(ctx::DCtx, bytes::Vector{UInt8}, ext::AbstractString)
    name = string("bonitodocs_", bytes_hash(bytes), ext)
    open(joinpath(ctx.builddir, name), "w") do io
        write(io, bytes)
    end
    return name
end
bytes_hash(bytes) = string(hash(bytes); base = 16)

function render_mime(ctx::DCtx, ::MIME"image/svg+xml", str)
    return DOM.img(; src = "data:image/svg+xml;base64," * base64encode(str))
end
function render_mime(ctx::DCtx, ::MIME"image/png", str)
    name = write_media(ctx, base64decode(str), ".png")
    return DOM.img(; src = name)
end
function render_mime(ctx::DCtx, ::MIME"image/jpeg", str)
    name = write_media(ctx, base64decode(str), ".jpeg")
    return DOM.img(; src = name)
end
function render_mime(ctx::DCtx, ::MIME"image/webp", str)
    name = write_media(ctx, base64decode(str), ".webp")
    return DOM.img(; src = name)
end
function render_mime(ctx::DCtx, ::MIME"image/gif", str)
    name = write_media(ctx, base64decode(str), ".gif")
    return DOM.img(; src = name)
end
function render_mime(ctx::DCtx, ::MIME"video/mp4", str)
    name = write_media(ctx, base64decode(str), ".mp4")
    return DOM.video(; src = name, controls = true, autoplay = true)
end

# ---- fallback --------------------------------------------------------------

function domify(ctx::DCtx, node::MA.Node, other)
    @debug "BonitoDocumenter: no domify method for $(typeof(other)); flattening to text."
    txt = try
        Documenter.MDFlatten.mdflatten(node)
    catch
        string(other)
    end
    return DOM.div(txt)
end
