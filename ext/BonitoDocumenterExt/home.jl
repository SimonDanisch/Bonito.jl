# Optional VitePress-style landing page.
#
# Configured via the `home` keyword of `DocumenterBonito`, e.g.
#
#     home = (
#         name = "Bonito",
#         text = "Interactive web apps in Julia",
#         tagline = "Build dashboards, docs and apps with one toolkit.",
#         image = "logo.svg",
#         actions = [(text="Get started", link="app.html", theme="brand"),
#                    (text="View on GitHub", link="https://...", theme="alt")],
#         features = [(icon="⚡", title="Fast", details="..."), ...],
#     )
#
# The markdown body of the home page (typically `index.md`) is rendered below the
# hero, so you can still write a normal introduction there.

get_field(nt, key, default) = hasproperty(nt, key) ? getproperty(nt, key) : default

function hero_dom(home; blog_link = nothing)
    main = Any[]
    name = get_field(home, :name, nothing)
    text = get_field(home, :text, nothing)
    tagline = get_field(home, :tagline, nothing)
    name === nothing || push!(main, DOM.span(name; class = "name"))
    text === nothing || push!(main, DOM.span(text; class = "text"))
    heading = DOM.h1(main...; class = "heading")

    blocks = Any[heading]
    tagline === nothing || push!(blocks, DOM.p(tagline; class = "tagline"))

    btns = Any[]
    for a in get_field(home, :actions, ())
        theme = get_field(a, :theme, "brand")
        push!(btns, DOM.a(a.text; class = "VPButton $(theme)", href = a.link))
    end
    # When a blog is configured, surface it as an extra hero action (unless the
    # user already added one pointing at the blog).
    if blog_link !== nothing && !any(a -> get_field(a, :link, "") == blog_link, get_field(home, :actions, ()))
        push!(btns, DOM.a("Blog"; class = "VPButton alt", href = blog_link))
    end
    isempty(btns) || push!(blocks, DOM.div(btns...; class = "actions"))

    cols = Any[DOM.div(blocks...; class = "main")]
    image = get_field(home, :image, nothing)
    image === nothing || push!(cols, DOM.div(DOM.img(; src = image, alt = something(name, "")); class = "image"))

    return DOM.div(cols...; class = "VPHero")
end

function features_dom(home)
    features = get_field(home, :features, ())
    isempty(features) && return nothing
    cards = map(features) do f
        icon = get_field(f, :icon, nothing)
        parts = Any[]
        icon === nothing || push!(parts, DOM.div(icon; class = "icon"))
        push!(parts, DOM.div(f.title; class = "title"))
        push!(parts, DOM.div(get_field(f, :details, ""); class = "details"))
        DOM.div(parts...; class = "VPFeature")
    end
    return DOM.div(cards...; class = "VPFeatures")
end

function home_page(ctx, home, content_dom; settings, version_label, search_index_script)
    blog_link = blog_enabled(ctx.doc, settings) ? "blog.html" : nothing
    hero = hero_dom(home; blog_link = blog_link)
    feats = features_dom(home)
    home_children = Any[hero]
    feats === nothing || push!(home_children, feats)
    push!(home_children, DOM.div(DOM.div(content_dom; class = "vp-doc"); class = "VPDoc"))
    body = DOM.div(
        DOM.div(home_children...; class = "VPHome");
        class = "VPContent is-home no-sidebar",
    )
    nav = navbar(settings, ctx.doc.user.sitename; version_label = version_label)
    return page_shell(; head_assets = head_assets(), navbar_dom = nav, body = body, search_index_script = search_index_script)
end
