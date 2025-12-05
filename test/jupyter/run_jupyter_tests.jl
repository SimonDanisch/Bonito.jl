#=
JupyterLab Smoke Test for Bonito

Tests Bonito rendering in JupyterLab using Electron.
Usage: julia --project=@. test/jupyter/run_jupyter_tests.jl
=#

using IJulia, HTTP, Electron, URIs, Random

const PORT = 8888
const POLL_INTERVAL = 5
const MAX_POLLS = 12
const TEST_DIR = @__DIR__
const NOTEBOOK_NAME = "bonito_test.ipynb"
const TOKEN_FILE = joinpath(TEST_DIR, "test_token.txt")
const JULIA_VERSION = "$(VERSION.major).$(VERSION.minor)"

# ─────────────────────────────────────────────────────────────────────────────
# Infrastructure
# ─────────────────────────────────────────────────────────────────────────────

function find_jupyter()
    path = IJulia.find_jupyter_subcommand("lab")
    !isnothing(path) && !isempty(path) && isfile(first(path)) && return first(path)
    jupyter = Sys.which("jupyter")
    !isnothing(jupyter) && return jupyter
    error("Could not find jupyter executable")
end

function start_server(jupyter)
    cmd = `$jupyter lab --no-browser --port=$PORT --IdentityProvider.token= --notebook-dir=$TEST_DIR`
    run(pipeline(cmd; stdout=devnull, stderr=devnull); wait=false)
end

function wait_for_server(; timeout=60)
    deadline = time() + timeout
    while time() < deadline
        try
            r = HTTP.get("http://127.0.0.1:$PORT/api";
                connect_timeout=2, readtimeout=2, retry=false, status_exception=false)
            r.status == 200 && return true
        catch; end
        sleep(1)
    end
    error("Server failed to start on port $PORT")
end

# ─────────────────────────────────────────────────────────────────────────────
# Electron Helpers
# ─────────────────────────────────────────────────────────────────────────────

function run_js(win, code::String)
    try
        Electron.run(win, code)
    catch
        nothing
    end
end

function has_text(win, text)
    escaped = replace(text, "'" => "\\'")
    run_js(win, "document.body.innerText.includes('$escaped')") === true
end

function click_selector(win, selector)
    run_js(win, """
        (function() {
            const el = document.querySelector('$selector');
            if (el) { el.click(); return true; }
            return false;
        })()
    """)
end

function select_option(win, selector, text)
    run_js(win, """
        (function() {
            const select = document.querySelector('$selector');
            if (!select) return false;
            for (let opt of select.options) {
                if (opt.text.includes('$text')) {
                    select.value = opt.value;
                    select.dispatchEvent(new Event('change', { bubbles: true }));
                    return true;
                }
            }
            return false;
        })()
    """)
end

# ─────────────────────────────────────────────────────────────────────────────
# Test Actions
# ─────────────────────────────────────────────────────────────────────────────

function handle_kernel_dialog!(win)
    sleep(2)
    if has_text(win, "Select Kernel")
        @info "Selecting Julia $JULIA_VERSION kernel..."
        select_option(win, ".jp-Dialog select", JULIA_VERSION)
        sleep(0.5)
        click_selector(win, ".jp-Dialog button.jp-mod-accept")
        sleep(2)
    end
end

function wait_for_idle_kernel(win; timeout=30)
    deadline = time() + timeout
    while time() < deadline
        has_text(win, "Idle") && return true
        sleep(1)
    end
    false
end

function run_cell!(win)
    run_js(win, """
        (function() {
            const el = document.querySelector('[title*="Run this cell"]');
            if (!el) return false;
            const btn = el.querySelector('button') || el;
            const rect = btn.getBoundingClientRect();
            ['mousedown', 'mouseup', 'click'].forEach(type => {
                btn.dispatchEvent(new MouseEvent(type, {
                    bubbles: true, cancelable: true, view: window,
                    clientX: rect.left + rect.width/2,
                    clientY: rect.top + rect.height/2
                }));
            });
            return true;
        })()
    """)
end

function wait_for_output(win, token)
    marker = "BONITO_TEST_SUCCESS_$token"
    for i in 1:MAX_POLLS
        has_text(win, marker) && return true
        @info "Waiting for output... ($i/$MAX_POLLS)"
        sleep(POLL_INTERVAL)
    end
    false
end

# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

# Use ELECTRON_OPTIONS from runtests.jl if available, otherwise define our own
if !@isdefined(ELECTRON_OPTIONS)
    const ELECTRON_OPTIONS = Dict{String, Any}(
        "show" => false,
        "focusOnWebView" => false,
    )
end

function run_test(jupyter)
    token = randstring(12)
    write(TOKEN_FILE, token)
    @info "Test token: $token"

    app = Electron.Application()
    proc = start_server(jupyter)

    try
        wait_for_server()
        win = Electron.Window(app, URI("http://localhost:$PORT/lab/tree/$NOTEBOOK_NAME"); options=ELECTRON_OPTIONS)
        sleep(5)

        handle_kernel_dialog!(win)
        wait_for_idle_kernel(win) || @warn "Kernel not idle, continuing..."

        @info "Running cell..."
        run_cell!(win)
        sleep(3)

        if wait_for_output(win, token)
            @info "PASSED"
            return true
        else
            @error "FAILED: Output not found"
            return false
        end
    finally
        kill(proc)
        close(app)
    end
end

"""
    run_jupyter_tests()

Entry point for running Jupyter tests.
Returns true if tests pass, false otherwise.
"""
function run_jupyter_tests()
    isfile(joinpath(TEST_DIR, NOTEBOOK_NAME)) || error("Test notebook not found")

    @info "Installing IJulia kernel..."
    IJulia.installkernel("Julia")

    jupyter = find_jupyter()
    @info "Using: $jupyter"

    return run_test(jupyter)
end

function main()
    passed = run_jupyter_tests()
    println("\n", "="^40)
    println("RESULT: ", passed ? "PASSED" : "FAILED")
    println("="^40)
    passed || error("Test failed")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
