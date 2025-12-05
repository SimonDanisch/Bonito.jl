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

"""
Get the cell execution prompt state (e.g., "[ ]:", "[*]:", "[1]:").
"""
function get_cell_prompt(win)
    result = run_js(win, """
        (function() {
            const prompt = document.querySelector('.jp-InputPrompt');
            return prompt ? prompt.textContent.trim() : '';
        })()
    """)
    return something(result, "")
end

"""
Execute the cell run action (focus cell, click run button, send Shift+Enter).
"""
function trigger_cell_run!(win)
    run_js(win, """
        (function() {
            // First, click on a cell to ensure it's focused
            const cell = document.querySelector('.jp-Cell');
            if (cell) {
                cell.click();
                cell.focus();
            }

            // Method 1: Try button click with MouseEvent dispatch
            const el = document.querySelector('[title*="Run this cell"]');
            if (el) {
                const btn = el.querySelector('button') || el;
                const rect = btn.getBoundingClientRect();
                ['mousedown', 'mouseup', 'click'].forEach(type => {
                    btn.dispatchEvent(new MouseEvent(type, {
                        bubbles: true, cancelable: true, view: window,
                        clientX: rect.left + rect.width/2,
                        clientY: rect.top + rect.height/2
                    }));
                });
                btn.click();
            }

            // Method 2: Try Shift+Enter keyboard shortcut on the notebook panel
            const notebook = document.querySelector('.jp-Notebook');
            if (notebook) {
                notebook.dispatchEvent(new KeyboardEvent('keydown', {
                    key: 'Enter', code: 'Enter', keyCode: 13,
                    shiftKey: true, bubbles: true, cancelable: true
                }));
            }
        })()
    """)
end

"""
Run cell with retry loop and DOM change detection.
Returns true if cell execution was detected (prompt changed from [ ]: to [*]: or [N]:).
"""
function run_cell!(win; max_retries=5, retry_delay=2)
    before = get_cell_prompt(win)
    @info "Cell prompt before: '$before'"

    for attempt in 1:max_retries
        @info "Run cell attempt $attempt/$max_retries"
        trigger_cell_run!(win)
        sleep(retry_delay)

        after = get_cell_prompt(win)
        @info "Cell prompt after: '$after'"

        # Success if prompt changed to [*]: (running) or [N]: (executed)
        if occursin(r"\[\*\]:", after) || occursin(r"\[\d+\]:", after)
            @info "Cell execution detected! Prompt: '$after'"
            return true
        end
    end

    @warn "Cell execution not detected after $max_retries attempts"
    return false
end

function wait_for_output(win, token)
    marker = "BONITO_TEST_SUCCESS_$token"
    for i in 1:MAX_POLLS
        has_text(win, marker) && return true
        @info "Waiting for output... ($i/$MAX_POLLS)"
        # On last poll, dump page info for debugging
        if i == MAX_POLLS
            debug_info = run_js(win, """
                (function() {
                    const cells = document.querySelectorAll('.jp-Cell');
                    const outputs = document.querySelectorAll('.jp-OutputArea-output');
                    const body = document.body.innerText.substring(0, 500);
                    return {
                        cellCount: cells.length,
                        outputCount: outputs.length,
                        bodyPreview: body
                    };
                })()
            """)
            @warn "Debug info on failure: $debug_info"
        end
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

# Additional Electron flags for CI headless environments
const CI_ELECTRON_FLAGS = [
    "--no-sandbox",
    "--disable-gpu",
    "--disable-dev-shm-usage",
    "--disable-software-rasterizer",
]

function run_test(jupyter)
    token = randstring(12)
    write(TOKEN_FILE, token)
    @info "Test token: $token"

    # Add CI flags if running in CI environment
    electron_args = haskey(ENV, "CI") ? CI_ELECTRON_FLAGS : String[]
    app = Electron.Application(; additional_electron_args=electron_args)
    proc = start_server(jupyter)

    try
        wait_for_server()
        win = Electron.Window(app, URI("http://localhost:$PORT/lab/tree/$NOTEBOOK_NAME"); options=ELECTRON_OPTIONS)
        sleep(5)

        handle_kernel_dialog!(win)
        wait_for_idle_kernel(win) || @warn "Kernel not idle, continuing..."

        # Check what JupyterLab APIs are available
        api_check = run_js(win, """
            (function() {
                const jl = window._JUPYTERLAB;
                return {
                    _JUPYTERLAB: !!jl,
                    keys: jl ? Object.keys(jl).slice(0, 10) : [],
                    hasApp: jl && !!jl.app,
                    hasCommands: jl && jl.app && !!jl.app.commands
                };
            })()
        """)
        @info "JupyterLab API check: $api_check"

        @info "Running cell..."
        cell_started = run_cell!(win)
        if !cell_started
            @warn "Cell may not have started, but checking for output anyway..."
        end

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
