# Documenter writer entry point: walk the Document and emit a Bonito static site.

"""Build the per-page search index entries (one per page + one per H2/H3)."""
function build_search_index(doc, flat)
    entries = NamedTuple{(:title, :text, :url), Tuple{String, String, String}}[]
    for l in flat
        page = get(doc.blueprint.pages, l.file, nothing)
        page === nothing && continue
        url = html_name(l.file)
        ptitle = page_title(page, l.title)
        push!(entries, (title = ptitle, text = page_text(page), url = url))
        for (lvl, id, htext) in page_outline(page)
            push!(entries, (title = htext, text = string(ptitle, " › ", htext), url = string(url, "#", id)))
        end
    end
    return entries
end

page_text(page) = first(Documenter.MDFlatten.mdflatten(page.mdast), 1500)

function json_escape(io::IO, s::AbstractString)
    for c in s
        if c == '"'; print(io, "\\\"")
        elseif c == '\\'; print(io, "\\\\")
        elseif c == '\n'; print(io, "\\n")
        elseif c == '\t'; print(io, "\\t")
        elseif c == '\r'; # drop
        elseif c < ' '; print(io, "\\u", string(UInt16(c), base = 16, pad = 4))
        else print(io, c)
        end
    end
end

function search_index_json(entries)
    io = IOBuffer()
    print(io, "[")
    for (i, e) in enumerate(entries)
        i > 1 && print(io, ",")
        print(io, "{\"title\":\""); json_escape(io, e.title)
        print(io, "\",\"text\":\""); json_escape(io, e.text)
        print(io, "\",\"url\":\""); json_escape(io, e.url)
        print(io, "\"}")
    end
    print(io, "]")
    return String(take!(io))
end

function render(doc::Documenter.Document, settings::BonitoFormat)
    @info "BonitoDocumenter: rendering Bonito documentation site."
    builddir = isabspath(doc.user.build) ? doc.user.build : joinpath(doc.user.root, doc.user.build)
    mkpath(builddir)

    groups, flat = build_nav(doc.user.pages)
    version_label = isempty(settings.version) ? nothing : settings.version

    index = build_search_index(doc, flat)
    search_script = DOM.script("window.__DOCS_SEARCH__ = $(search_index_json(index));")

    # Shared asset server so every page writes into the same `build/bonito` folder
    # (matching the paths baked into the already-rendered inline app fragments).
    assets = Bonito.DocumenterAssets()
    assets.folder[] = builddir

    for (src, page) in doc.blueprint.pages
        ctx = DCtx(doc, page, settings, builddir)
        content = domify_children(ctx, page.mdast)
        title = page_title(page, doc.user.sitename)

        is_home = settings.home !== nothing && samefile(src, settings.home_page)
        shell = if is_home
            home_page(ctx, settings.home, content;
                settings = settings, version_label = version_label, search_index_script = search_script)
        else
            outline = page_outline(page)
            doc_page(ctx, content;
                groups = groups, flat = flat, current_src = src, settings = settings,
                outline = outline, version_label = version_label, search_index_script = search_script)
        end

        app = Bonito.App(shell; title = title)
        outpath = joinpath(builddir, html_name(src))
        mkpath(dirname(outpath))
        # `invokelatest`: example apps were evaluated in earlier world ages, so run
        # the render + serialization at the current world to avoid world-age errors
        # when packing values whose methods were added after the block was eval'd.
        Base.invokelatest(Bonito.export_static, outpath, app;
            asset_server = assets, connection = Bonito.NoConnection())
    end

    @info "BonitoDocumenter: wrote $(length(doc.blueprint.pages)) pages to $(builddir)."

    build_blog(doc, settings, builddir, assets;
        version_label = version_label, search_index_script = search_script)
    return
end
