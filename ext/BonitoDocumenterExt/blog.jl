# Blog subsystem, modeled on BonitoSites (folder-per-post: `post.xml` metadata +
# `post.md` content + an `images/` folder). It is self-contained on purpose:
# BonitoSites depends on Bonito, so the extension can't depend on it without a
# cycle (and it pulls heavy deps). Instead we reuse the extension's own
# markdown -> Bonito DOM pipeline (`domify`) and page chrome (`navbar`,
# `page_shell`).
#
# Output is kept FLAT at the build root (index -> `blog.html`, each post ->
# `<slug>.html`, images -> `<slug>/<file>`). `DocumenterAssets` resolves asset
# URLs — and the navbar links — relative to the build root, so nesting blog pages
# in subfolders would break both.

struct BlogPost
    slug::String          # post folder name; output file is `<slug>.html`
    dir::String           # source folder
    title::String
    date::Dates.DateTime
    description::String
    image::String         # source path of the card image ("" if none / remote keeps URL)
    mdast::Any            # parsed MarkdownAST document
end

post_html(slug) = slug * ".html"

is_remote(url) = startswith(url, "http://") || startswith(url, "https://") || startswith(url, "//")

# ---- post.xml parsing (the flat BonitoSites schema) ------------------------

function xml_unescape(s)
    s = replace(s, "&lt;" => "<")
    s = replace(s, "&gt;" => ">")
    s = replace(s, "&quot;" => "\"")
    s = replace(s, "&#39;" => "'", "&apos;" => "'")
    s = replace(s, "&amp;" => "&")   # last, so "&amp;lt;" -> "&lt;" stays literal
    return s
end

"""Extract the (trimmed, entity-decoded) text content of `<tag>…</tag>` from a flat xml string."""
function xml_content(xml::AbstractString, tag::AbstractString)
    m = match(Regex("<$(tag)\\b[^>]*>\\s*(.*?)\\s*</$(tag)>", "s"), xml)
    return m === nothing ? "" : xml_unescape(String(strip(m.captures[1])))
end

const BLOG_DATE_FORMATS = (
    Dates.DateFormat("e, d u Y H:M:S"),
    Dates.DateFormat("e, d u Y"),
    Dates.DateFormat("d u Y"),
    Dates.DateFormat("yyyy-mm-dd"),
)

function parse_blog_date(s)
    s = strip(s)
    isempty(s) && return Dates.DateTime(0)
    for fmt in BLOG_DATE_FORMATS
        d = tryparse(Dates.DateTime, s, fmt)
        d === nothing || return d
    end
    @warn "BonitoDocumenter: could not parse blog date $(repr(s)); ordering it last."
    return Dates.DateTime(0)
end

function blog_md_title(mdast, fallback)
    for c in mdast.children
        if c.element isa MA.Heading && c.element.level == 1
            return Documenter.MDFlatten.mdflatten(c)
        end
    end
    return fallback
end

function load_post(dir)
    slug = basename(normpath(dir))
    mdpath = joinpath(dir, "post.md")
    isfile(mdpath) || error("Blog post $(dir) is missing post.md")
    title = ""; desc = ""; datestr = ""; image = ""
    xmlpath = joinpath(dir, "post.xml")
    if isfile(xmlpath)
        xml = read(xmlpath, String)
        title = xml_content(xml, "title")
        desc = xml_content(xml, "description")
        datestr = xml_content(xml, "pubDate")
        url = xml_content(xml, "url")   # nested <image><url>…</url></image>
        if !isempty(url)
            image = is_remote(url) ? url : normpath(joinpath(dir, replace(url, "./" => "")))
        end
    end
    mdast = convert(MA.Node, Markdown.parse(read(mdpath, String)))
    isempty(title) && (title = blog_md_title(mdast, slug))
    return BlogPost(slug, dir, title, parse_blog_date(datestr), desc, image, mdast)
end

function load_posts(blogdir)
    posts = BlogPost[]
    for entry in readdir(blogdir; join = true)
        isdir(entry) && isfile(joinpath(entry, "post.md")) || continue
        push!(posts, load_post(entry))
    end
    sort!(posts; by = p -> p.date, rev = true)
    return posts
end

# ---- asset relocation ------------------------------------------------------

walk_nodes(f, n) = (f(n); for c in n.children; walk_nodes(f, c); end)

"""Copy a post's local images into `build/<slug>/` and rewrite the markdown image
destinations to the new (root-relative) location."""
function relocate_images!(post::BlogPost, builddir)
    outdir = joinpath(builddir, post.slug)
    walk_nodes(post.mdast) do n
        el = n.element
        el isa MA.Image || return
        is_remote(el.destination) && return
        src = normpath(joinpath(post.dir, replace(el.destination, "./" => "")))
        if isfile(src)
            isdir(outdir) || mkpath(outdir)
            cp(src, joinpath(outdir, basename(src)); force = true)
            n.element = MA.Image(post.slug * "/" * basename(src), el.title)
        else
            @warn "BonitoDocumenter: blog image not found: $(src)"
        end
    end
    return post
end

"""Copy a post's card image into `build/<slug>/` and return its root-relative URL."""
function relocate_card_image(post::BlogPost, builddir)
    isempty(post.image) && return ""
    is_remote(post.image) && return post.image
    isfile(post.image) || (@warn("BonitoDocumenter: blog card image not found: $(post.image)"); return "")
    outdir = joinpath(builddir, post.slug)
    isdir(outdir) || mkpath(outdir)
    cp(post.image, joinpath(outdir, basename(post.image)); force = true)
    return post.slug * "/" * basename(post.image)
end

human_date(d) = d == Dates.DateTime(0) ? "" : Dates.format(d, "U d, Y")

# ---- DOM ------------------------------------------------------------------

function blog_card(post::BlogPost, builddir)
    img_url = relocate_card_image(post, builddir)
    media = isempty(img_url) ? nothing :
        DOM.div(DOM.img(; src = img_url, alt = post.title); class = "blog-card-media")
    dateline = human_date(post.date)
    body = Any[]
    isempty(dateline) || push!(body, DOM.div(dateline; class = "blog-card-date"))
    push!(body, DOM.h3(post.title; class = "blog-card-title"))
    isempty(post.description) || push!(body, DOM.p(post.description; class = "blog-card-desc"))
    return DOM.a(
        media, DOM.div(body...; class = "blog-card-body");
        class = "blog-card", href = post_html(post.slug),
    )
end

function blog_index_body(doc, posts, settings, builddir)
    cards = [blog_card(p, builddir) for p in posts]
    rss = DOM.link(; rel = "alternate", type = "application/rss+xml",
        title = "$(doc.user.sitename) Blog", href = "feed.xml")
    return DOM.div(
        DOM.div(
            rss,
            DOM.h1("Blog"; class = "blog-index-title"),
            DOM.div(cards...; class = "blog-grid");
            class = "blog-container",
        );
        class = "VPContent is-blog no-sidebar",
    )
end

function blog_post_body(doc, post, settings, builddir)
    relocate_images!(post, builddir)
    ctx = DCtx(doc, (; source = "$(settings.blog)/$(post.slug)/post.md"), settings, builddir)
    content = domify_children(ctx, post.mdast)
    meta = Any[DOM.a("← Back to blog"; class = "blog-back", href = "blog.html")]
    dl = human_date(post.date)
    isempty(dl) || push!(meta, DOM.div(dl; class = "blog-post-date"))
    article = DOM.div(
        DOM.div(meta...; class = "blog-post-meta"),
        DOM.div(content...; class = "vp-doc");
        class = "blog-article",
    )
    main = DOM.div(DOM.div(DOM.div(article; class = "doc-content"); class = "VPDoc"); class = "VPMain")
    return DOM.div(main; class = "VPContent is-blog no-sidebar")
end

# ---- RSS ------------------------------------------------------------------

function xml_escape(s)
    s = replace(s, "&" => "&amp;")
    s = replace(s, "<" => "&lt;")
    s = replace(s, ">" => "&gt;")
    return s
end

function write_blog_rss(path, posts, doc, settings)
    io = IOBuffer()
    println(io, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
    println(io, "<rss version=\"2.0\"><channel>")
    println(io, "<title>", xml_escape(doc.user.sitename), " Blog</title>")
    println(io, "<link>", xml_escape(isempty(settings.repo) ? "" : repo_url(settings.repo)), "</link>")
    println(io, "<description>", xml_escape(doc.user.sitename), " blog</description>")
    for p in posts
        println(io, "<item>")
        println(io, "<title>", xml_escape(p.title), "</title>")
        println(io, "<link>", xml_escape(post_html(p.slug)), "</link>")
        println(io, "<guid isPermaLink=\"false\">", xml_escape(p.slug), "</guid>")
        isempty(p.description) || println(io, "<description>", xml_escape(p.description), "</description>")
        p.date == Dates.DateTime(0) ||
            println(io, "<pubDate>", Dates.format(p.date, "e, dd u yyyy HH:MM:SS"), " +0000</pubDate>")
        println(io, "</item>")
    end
    println(io, "</channel></rss>")
    write(path, String(take!(io)))
    return
end

# ---- orchestration --------------------------------------------------------

function blog_source_dir(doc, settings)
    settings.blog === nothing && return nothing
    p = settings.blog
    return isabspath(p) ? p : joinpath(doc.user.root, p)
end

blog_enabled(doc, settings) = (d = blog_source_dir(doc, settings); d !== nothing && isdir(d))

function build_blog(doc, settings, builddir, assets; version_label, search_index_script)
    blogdir = blog_source_dir(doc, settings)
    (blogdir === nothing || !isdir(blogdir)) && return BlogPost[]
    posts = load_posts(blogdir)
    isempty(posts) && return posts

    export_page(body, file, title) = begin
        nav = navbar(settings, doc.user.sitename; version_label = version_label)
        shell = page_shell(; head_assets = head_assets(), navbar_dom = nav,
            body = body, search_index_script = search_index_script)
        app = Bonito.App(shell; title = title)
        outpath = joinpath(builddir, file)
        mkpath(dirname(outpath))
        Base.invokelatest(Bonito.export_static, outpath, app;
            asset_server = assets, connection = Bonito.NoConnection())
    end

    export_page(blog_index_body(doc, posts, settings, builddir), "blog.html", "Blog | $(doc.user.sitename)")
    for p in posts
        export_page(blog_post_body(doc, p, settings, builddir), post_html(p.slug), "$(p.title) | $(doc.user.sitename)")
    end
    write_blog_rss(joinpath(builddir, "feed.xml"), posts, doc, settings)

    @info "BonitoDocumenter: wrote blog ($(length(posts)) post$(length(posts) == 1 ? "" : "s")) to $(builddir)."
    return posts
end
