# Custom `@example` / `@setup` expanders for the Bonito writer.
#
# Instead of letting Documenter's expanders evaluate the block and immediately
# `display_dict`/`show` the result into an HTML string, we evaluate it ourselves
# and keep the LIVE result (a Bonito `App`, a Makie figure, a plain value, …).
# The writer then drops the real object straight into the page DOM — `DOM.div(app)`
# — so it renders through that page's own Bonito session, exactly like any other
# Bonito page. No `show` interception, no global state, no `Page()`.
#
# The sandbox uses our own `"bonito"` module prefix. Documenter's `clear_modules!`
# only deletes modules keyed `__atexample__*`, so ours survive until the writer
# runs and an app that references an example-defined helper still resolves.
#
# Both expanders are gated on the active format being `BonitoFormat`, so a normal
# `Documenter.HTML` build (even with Bonito loaded) keeps Documenter's behaviour.

"""Holds the live result of a `@example` block until the writer renders it."""
struct BonitoExample <: Documenter.AbstractDocumenterBlock
    codeblock::MA.CodeBlock   # original block (required by AbstractDocumenterBlock / mdflatten)
    input::String             # source to display (with `# hide` lines dropped)
    result::Any               # the live value returned by the block (App, figure, …)
    stdout::String            # captured stdout/stderr
end

is_bonito_build(doc) = any(f -> f isa BonitoFormat, doc.user.format)
share_default(page) = get(page.globals.meta, :ShareDefaultModule, false)

# ---- @example --------------------------------------------------------------

abstract type BonitoExampleBlocks <: Documenter.Expanders.ExpanderPipeline end
Documenter.Selectors.order(::Type{BonitoExampleBlocks}) = 7.5  # before Documenter's ExampleBlocks (8.0)
Documenter.Selectors.matcher(::Type{BonitoExampleBlocks}, node, page, doc) =
    is_bonito_build(doc) && Documenter.iscode(node, r"^@example")

function Documenter.Selectors.runner(::Type{BonitoExampleBlocks}, node, page, doc)
    x = node.element
    matched = match(r"^@example(?:\s+([^\s;]+))?\s*(;.*)?$", x.info)
    matched === nothing && error("invalid '@example' syntax: $(x.info)")
    name, kwargs = matched.captures

    if Documenter.is_draft(doc, page)
        Documenter.create_draft_result!(node; blocktype = "@example")
        return
    end

    sandbox = Documenter.get_sandbox_module!(page.globals.meta, "bonito", name; share_default_module = share_default(page))
    sym = nameof(sandbox)
    lines = Documenter.find_block_in_file(x.code, page.source)

    continued = false
    ansicolor = Documenter._any_color_fmt(doc)
    if kwargs !== nothing
        continued = occursin(r"\bcontinued\s*=\s*true\b", kwargs)
        m2 = match(r"\bansicolor\s*=\s*(true|false)\b", kwargs)
        m2 !== nothing && (ansicolor = m2[1] == "true")
    end

    result, buffer = nothing, IOBuffer()
    if !continued
        if haskey(page.globals.meta, :ContinuedCode) && haskey(page.globals.meta[:ContinuedCode], sym)
            code = page.globals.meta[:ContinuedCode][sym] * '\n' * x.code
            delete!(page.globals.meta[:ContinuedCode], sym)
        else
            code = x.code
        end
        ln = LineNumberNode(lines === nothing ? 0 : lines.first, basename(page.source))
        for (ex, str) in Documenter.parseblock(code, doc, page; keywords = false, linenumbernode = ln, lines = lines)
            c = Documenter.IOCapture.capture(rethrow = InterruptException, color = ansicolor) do
                cd(page.workdir) do
                    Core.eval(sandbox, ex)
                end
            end
            Core.eval(sandbox, Expr(:global, Expr(:(=), :ans, QuoteNode(c.value))))
            result = c.value
            print(buffer, c.output)
            if c.error
                bt = Documenter.remove_common_backtrace(c.backtrace)
                Documenter.@docerror(doc, :example_block, """
                    failed to run `@example` block in $(Documenter.locrepr(doc, page, lines))
                    ```$(x.info)
                    $(x.code)
                    ```
                    """, exception = (c.value, bt))
                return
            end
        end
    else
        CC = get!(page.globals.meta, :ContinuedCode, Dict())
        CC[sym] = get(CC, sym, "") * '\n' * x.code
    end

    node.element = BonitoExample(x, Documenter.droplines(x.code), result, String(take!(buffer)))
    return
end

# ---- @setup ----------------------------------------------------------------

abstract type BonitoSetupBlocks <: Documenter.Expanders.ExpanderPipeline end
Documenter.Selectors.order(::Type{BonitoSetupBlocks}) = 7.5
Documenter.Selectors.matcher(::Type{BonitoSetupBlocks}, node, page, doc) =
    is_bonito_build(doc) && Documenter.iscode(node, r"^@setup")

function Documenter.Selectors.runner(::Type{BonitoSetupBlocks}, node, page, doc)
    x = node.element
    matched = match(r"^@setup(?:\s+([^\s;]+))?\s*$", x.info)
    matched === nothing && error("invalid '@setup <name>' syntax: $(x.info)")
    name = matched[1]

    if Documenter.is_draft(doc, page)
        Documenter.create_draft_result!(node; blocktype = "@setup")
        return
    end

    sandbox = Documenter.get_sandbox_module!(page.globals.meta, "bonito", name; share_default_module = share_default(page))
    try
        cd(page.workdir) do
            include_string(sandbox, x.code)
        end
    catch err
        lines = Documenter.find_block_in_file(x.code, page.source)
        Documenter.@docerror(doc, :setup_block, """
            failed to run `@setup` block in $(Documenter.locrepr(doc, page, lines))
            ```$(x.info)
            $(x.code)
            ```
            """, exception = err)
    end
    node.element = Documenter.SetupNode(x.info, x.code)
    return
end
