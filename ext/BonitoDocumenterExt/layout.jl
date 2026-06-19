# Site chrome: navbar, sidebar, outline aside, doc footer, search modal.
# Recreates the VitePress default-theme layout structure as Bonito DOM.

# ---- assets (shared & deduped across pages) --------------------------------

const ASSET_DIR = joinpath(@__DIR__, "assets")
const THEME_CSS = Bonito.Asset(joinpath(ASSET_DIR, "theme.css"))
const DOCS_JS = Bonito.Asset(joinpath(ASSET_DIR, "docs.js"))

const KATEX_CSS = Bonito.Asset("https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css")
const KATEX_JS = Bonito.Asset("https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.js")
const KATEX_AUTORENDER = Bonito.Asset("https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/contrib/auto-render.min.js")

# ---- small svg icons -------------------------------------------------------

icon(svg; kw...) = DOM.m_unesc("span", svg; style = "display:inline-flex", kw...)

const ICON_SUN = """<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="5"></circle><line x1="12" y1="1" x2="12" y2="3"></line><line x1="12" y1="21" x2="12" y2="23"></line><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"></line><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"></line><line x1="1" y1="12" x2="3" y2="12"></line><line x1="21" y1="12" x2="23" y2="12"></line><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"></line><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"></line></svg>"""
const ICON_GITHUB = """<svg viewBox="0 0 24 24" width="20" height="20" fill="currentColor"><path d="M12 .297c-6.63 0-12 5.373-12 12 0 5.303 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61C4.422 18.07 3.633 17.7 3.633 17.7c-1.087-.744.084-.729.084-.729 1.205.084 1.838 1.236 1.838 1.236 1.07 1.835 2.809 1.305 3.495.998.108-.776.417-1.305.76-1.605-2.665-.3-5.466-1.332-5.466-5.93 0-1.31.465-2.38 1.235-3.22-.135-.303-.54-1.523.105-3.176 0 0 1.005-.322 3.3 1.23.96-.267 1.98-.399 3-.405 1.02.006 2.04.138 3 .405 2.28-1.552 3.285-1.23 3.285-1.23.645 1.653.24 2.873.12 3.176.765.84 1.23 1.91 1.23 3.22 0 4.61-2.805 5.625-5.475 5.92.42.36.81 1.096.81 2.22 0 1.606-.015 2.896-.015 3.286 0 .315.21.69.825.57C20.565 22.092 24 17.592 24 12.297c0-6.627-5.373-12-12-12"></path></svg>"""
const ICON_MENU = """<svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><line x1="3" y1="6" x2="21" y2="6"></line><line x1="3" y1="12" x2="21" y2="12"></line><line x1="3" y1="18" x2="21" y2="18"></line></svg>"""
const ICON_SEARCH = """<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="8"></circle><line x1="21" y1="21" x2="16.65" y2="16.65"></line></svg>"""

# ---- navigation model ------------------------------------------------------

struct NavLink
    title::String
    file::String   # source-relative md path (matches blueprint key)
end

const NavGroup = Tuple{Union{Nothing, String}, Vector{NavLink}}

"""
    build_nav(pages) -> (groups, flat)

Parse Documenter's `pages=` structure into sidebar `groups`
(`(title_or_nothing, links)`) and a `flat` ordered list of links (used for
prev/next and search).
"""
function build_nav(pages)
    groups = NavGroup[]
    flat = NavLink[]
    loose = NavLink[]   # accumulates ungrouped top-level links

    flush_loose!() = (isempty(loose) || (push!(groups, (nothing, copy(loose))); empty!(loose)))

    collect_links(entry) = begin
        out = NavLink[]
        _collect!(out, entry)
        out
    end

    for entry in pages
        if entry isa AbstractString
            l = NavLink(default_title(entry), entry); push!(loose, l); push!(flat, l)
        elseif entry isa Pair && entry.second isa AbstractString
            l = NavLink(String(entry.first), entry.second); push!(loose, l); push!(flat, l)
        elseif entry isa Pair   # titled group with nested content
            flush_loose!()
            links = collect_links(entry.second)
            append!(flat, links)
            push!(groups, (String(entry.first), links))
        else                    # bare nested vector
            flush_loose!()
            links = collect_links(entry)
            append!(flat, links)
            push!(groups, (nothing, links))
        end
    end
    flush_loose!()
    return groups, flat
end

function _collect!(out, entry)
    if entry isa AbstractString
        push!(out, NavLink(default_title(entry), entry))
    elseif entry isa Pair && entry.second isa AbstractString
        push!(out, NavLink(String(entry.first), entry.second))
    elseif entry isa Pair
        _collect!(out, entry.second)
    elseif entry isa AbstractVector
        for sub in entry
            _collect!(out, sub)
        end
    end
    return out
end

default_title(file) = titlecase(replace(splitext(basename(file))[1], r"[-_]" => " "))

samefile(a, b) = splitext(normpath(a))[1] == splitext(normpath(b))[1]
html_name(file) = splitext(replace(file, "\\" => "/"))[1] * ".html"

# ---- page metadata ---------------------------------------------------------

function page_title(page, fallback)
    for node in page.mdast.children
        h = node
        if node.element isa Documenter.AnchoredHeader
            h = first(node.children)
        end
        if h.element isa MA.Heading && h.element.level == 1
            return Documenter.MDFlatten.mdflatten(h)
        end
    end
    return fallback
end

function page_outline(page)
    items = Tuple{Int, String, String}[]
    for node in page.mdast.children
        node.element isa Documenter.AnchoredHeader || continue
        h = first(node.children)
        lvl = h.element.level
        2 <= lvl <= 3 || continue
        id = Documenter.anchor_label(node.element.anchor)
        push!(items, (lvl, id, Documenter.MDFlatten.mdflatten(h)))
    end
    return items
end

# ---- chrome components -----------------------------------------------------

function navbar(settings, sitename; version_label, has_sidebar = true)
    right = Any[]
    if settings.blog !== nothing
        push!(right, DOM.div(DOM.a("Blog"; href = "blog.html"); class = "nav-links"))
    end
    push!(right, DOM.button(
        icon(ICON_SEARCH), DOM.span("Search"), DOM.span("Ctrl K"; class = "kbd");
        class = "search-btn", dataOpenSearch = true, type = "button",
    ))
    if version_label !== nothing
        push!(right, version_switcher(version_label))
    end
    if !isempty(settings.repo)
        push!(right, DOM.a(icon(ICON_GITHUB); class = "icon-btn", href = repo_url(settings.repo), target = "_blank", title = "GitHub"))
    end
    push!(right, DOM.button(icon(ICON_SUN); class = "icon-btn", dataToggleTheme = true, type = "button", title = "Toggle theme"))
    # The hamburger only toggles the sidebar, so it's pointless on pages that
    # don't have one (the landing page and blog).
    if has_sidebar
        push!(right, DOM.button(icon(ICON_MENU); class = "icon-btn hamburger", dataToggleSidebar = true, type = "button", title = "Menu"))
    end

    title_children = Any[]
    settings.logo === nothing || push!(title_children, DOM.img(; src = settings.logo, alt = sitename))
    push!(title_children, DOM.span(sitename))
    title = DOM.a(title_children...; class = "title", href = "index.html")
    return DOM.div(DOM.div(title, DOM.div(right...; class = "content"); class = "container"); class = "VPNav")
end

repo_url(repo) = startswith(repo, "http") ? repo : "https://" * repo

function version_switcher(label)
    return DOM.div(
        # `versions.js` is emitted by Documenter's `deploydocs` one level above the
        # per-version site; harmlessly 404s for a local single-version build.
        DOM.script(; src = "../versions.js"),
        DOM.button(DOM.span(label), DOM.span("▾"); class = "trigger", type = "button"),
        DOM.div(; class = "menu", dataVersions = true);
        class = "VPVersion",
    )
end

function sidebar(doc, groups, current_src)
    children = Any[]
    for (title, links) in groups
        linkdoms = map(links) do l
            cls = "link" * (samefile(l.file, current_src) ? " active" : "")
            DOM.a(l.title; class = cls, href = html_name(l.file))
        end
        if title === nothing
            append!(children, linkdoms)
        else
            push!(children, DOM.div(DOM.div(title; class = "group-title"), linkdoms...; class = "group"))
        end
    end
    return (
        DOM.nav(children...; class = "VPSidebar"),
        DOM.div(; class = "VPSidebar-backdrop"),
    )
end

function aside(outline)
    isempty(outline) && return DOM.div(; class = "VPAside")
    links = map(outline) do (lvl, id, text)
        DOM.a(text; href = "#" * id, class = "lvl-$(lvl)")
    end
    return DOM.div(
        DOM.div(
            DOM.div("On this page"; class = "outline-title"),
            DOM.nav(links...; class = "outline");
            class = "aside-inner",
        );
        class = "VPAside",
    )
end

function doc_footer(settings, flat, current_src, page)
    idx = findfirst(l -> samefile(l.file, current_src), flat)
    prevn = (idx !== nothing && idx > 1) ? flat[idx - 1] : nothing
    nextn = (idx !== nothing && idx < length(flat)) ? flat[idx + 1] : nothing

    edit = Any[]
    if !isempty(settings.repo)
        url = edit_url(settings, page)
        url === nothing || push!(edit, DOM.div(DOM.a("Edit this page"; href = url, target = "_blank"); class = "edit-link"))
    end

    pagers = Any[]
    if prevn !== nothing
        push!(pagers, DOM.a(DOM.span("Previous"; class = "desc"), DOM.span(prevn.title; class = "title");
            class = "pager-link prev", href = html_name(prevn.file)))
    else
        push!(pagers, DOM.div())
    end
    if nextn !== nothing
        push!(pagers, DOM.a(DOM.span("Next"; class = "desc"), DOM.span(nextn.title; class = "title");
            class = "pager-link next", href = html_name(nextn.file)))
    else
        push!(pagers, DOM.div())
    end

    return DOM.footer(
        DOM.div(edit...; class = "edit-info"),
        DOM.nav(pagers...; class = "prev-next");
        class = "VPDocFooter",
    )
end

function edit_url(settings, page)
    isempty(settings.repo) && return nothing
    base = repo_url(settings.repo)
    return string(base, "/blob/", settings.devbranch, "/docs/", page.source)
end

function search_modal()
    return DOM.div(
        DOM.div(
            DOM.div(
                icon(ICON_SEARCH),
                DOM.input(; type = "text", placeholder = "Search docs", autocomplete = "off", spellcheck = "false");
                class = "search-bar",
            ),
            DOM.div(; class = "results");
            class = "VPSearch",
        );
        class = "VPSearch-backdrop",
    )
end

# ---- full page assembly ----------------------------------------------------

function page_shell(; head_assets, navbar_dom, body, search_index_script)
    return DOM.div(
        head_assets...,
        navbar_dom,
        body,
        search_modal(),
        search_index_script;
        class = "bonito-docs vp-layout",
    )
end

# Assets that must be present on every page (CSS in <head> region of body).
head_assets() = Any[
    THEME_CSS, KATEX_CSS,
    KATEX_JS, KATEX_AUTORENDER,
    DOCS_JS,
]

function doc_page(ctx, content_dom; groups, flat, current_src, settings, outline, version_label, search_index_script)
    sb, backdrop = sidebar(ctx.doc, groups, current_src)
    main = DOM.div(
        DOM.div(
            DOM.div(
                DOM.div(content_dom; class = "vp-doc"),
                doc_footer(settings, flat, current_src, ctx.page);
                class = "doc-content",
            ),
            aside(outline);
            class = "doc-container",
        );
        class = "VPDoc",
    )
    body = DOM.div(
        sb, backdrop,
        DOM.div(main; class = "VPMain");
        class = "VPContent",
    )
    nav = navbar(settings, ctx.doc.user.sitename; version_label = version_label)
    return page_shell(; head_assets = head_assets(), navbar_dom = nav, body = body, search_index_script = search_index_script)
end
