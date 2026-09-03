# Notebook display (Pluto / IJulia): every output has to stand on its own.
#
# In parent-session mode the first `show` renders the root bootstrap — Bonito
# library import, connection setup, root `init_session` — followed by a
# subsession; every later `show` rendered the subsession alone. An output that
# is re-rendered without the first one (page reload, static HTML export, or the
# first cell re-run and its output replaced) therefore never came up: `Bonito`
# was undefined and the root never initialized. Now every output repeats the
# bootstrap, and `Bonito.init_session` ignores the copies once the root is live.

# The inline init scripts are data-URL module scripts under `NoServer`; decode
# them so the assertions can look at the actual `init_session` calls.
function inline_module_scripts(html::AbstractString)
    pattern = r"<script src=\"data:application/javascript;base64,([A-Za-z0-9+/=]+)\" type=\"module\">"
    return [String(Base64.base64decode(m.captures[1])) for m in eachmatch(pattern, html)]
end

function root_init_calls(html::AbstractString, root_id::AbstractString)
    return count(s -> occursin("Bonito.init_session(\"$(root_id)\"", s), inline_module_scripts(html))
end

function notebook_output_app(text)
    return App(; indicator=nothing) do session
        target = DOM.div("waiting"; class="init-target")
        return DOM.div(target, js"$(target).innerText = $(text);")
    end
end

function write_page(dir, name, body)
    path = joinpath(dir, name)
    write(path, "<!doctype html><html><head><meta charset=\"UTF-8\"></head><body>$(body)</body></html>")
    return path
end

function init_targets(window)
    return run(window, "Array.from(document.querySelectorAll('.init-target')).map(x => x.innerText)")
end

@testset "notebook outputs are self-contained" begin
    # Offline + inlined assets + one root per page: what Pluto/IJulia get,
    # minus the websocket (which a static snapshot never has anyway).
    Bonito.Page(; offline=true, exportable=true)
    dir = mktempdir()
    try
        html1 = sprint(io -> show(io, MIME"text/html"(), notebook_output_app("first")))
        html2 = sprint(io -> show(io, MIME"text/html"(), notebook_output_app("second")))
        root = Bonito.CURRENT_SESSION[]
        @test root isa Session
        @test Bonito.get_metadata(root, Bonito.ROOT_BOOTSTRAP_KEY) isa Hyperscript.Node

        lib = Bonito.url(root, Bonito.BonitoLib)
        # First output: root bootstrap + subsession, as before.
        @test count(lib, html1) == 1
        @test root_init_calls(html1, root.id) == 1
        # Every later output repeats the bootstrap exactly once.
        @test count(lib, html2) == 1
        @test root_init_calls(html2, root.id) == 1
        @test occursin("bonito-root-bootstrap", html2)
        @test !occursin("bonito-root-bootstrap", html1)

        # A page that only has the second output — the first cell's output is
        # gone (re-run) or simply not part of the page.
        window = TestWindow(URI("file://" * write_page(dir, "second_only.html", html2)))
        try
            @test Bonito.wait_for(() -> init_targets(window) == ["second"]) == :success
        finally
            close(window)
        end

        # Both outputs, in reverse order, so the repeated bootstrap runs before
        # the original one: everything initializes and the root comes up once.
        window = TestWindow(URI("file://" * write_page(dir, "reversed.html", html2 * html1)))
        try
            @test Bonito.wait_for(() -> init_targets(window) == ["second", "first"]) == :success
            roots = run(window, "Object.values(Bonito.Sessions.SESSIONS).filter(s => s[1] === 'root').length")
            @test roots == 1
        finally
            close(window)
        end
    finally
        Bonito.Page(; offline=false, exportable=false)
        Bonito.force_subsession!(false)
    end
end
