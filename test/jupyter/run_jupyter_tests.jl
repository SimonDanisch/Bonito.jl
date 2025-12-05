#=
Jupyter Smoke Tests for Bonito

Tests Bonito rendering in JupyterLab using Electron.
Uses a pre-made notebook to avoid CodeMirror manipulation complexity.

Usage: julia --project=@. test/jupyter/run_jupyter_tests.jl
=#

using IJulia, HTTP, Electron, URIs

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

const PORT = 8888
const POLL_INTERVAL = 5
const MAX_POLLS = 12

const TEST_DIR = @__DIR__
const NOTEBOOK_NAME = "bonito_test.ipynb"
const JULIA_VERSION_STR = "$(VERSION.major).$(VERSION.minor)"

# ─────────────────────────────────────────────────────────────────────────────
# Infrastructure
# ─────────────────────────────────────────────────────────────────────────────

"""Find jupyter executable via IJulia or PATH."""
function find_jupyter()
    path = IJulia.find_jupyter_subcommand("lab")
    !isnothing(path) && !isempty(path) && isfile(first(path)) && return first(path)
    jupyter = Sys.which("jupyter")
    !isnothing(jupyter) && return jupyter
    error("Could not find jupyter executable")
end

"""Start a Jupyter server in the test directory."""
function start_server(jupyter)
    cmd = `$jupyter lab --no-browser --port=$PORT --IdentityProvider.token= --notebook-dir=$TEST_DIR`
    run(pipeline(cmd; stdout=devnull, stderr=devnull); wait=false)
end

"""Block until server responds."""
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
    error("Server on port $PORT failed to start")
end

# ─────────────────────────────────────────────────────────────────────────────
# Electron Helpers
# ─────────────────────────────────────────────────────────────────────────────

"""Run JavaScript in Electron window and return result."""
function run_js(win, code::String)
    try
        return Electron.run(win, code)
    catch e
        @debug "JS execution failed" code exception=e
        return nothing
    end
end

"""Check if text exists on page."""
function has_text(win, text)
    escaped = replace(text, "'" => "\\'")
    run_js(win, "document.body.innerText.includes('$escaped')") === true
end

"""Click element matching selector."""
function click_selector(win, selector)
    run_js(win, """
        (function() {
            const el = document.querySelector('$selector');
            if (el) { el.click(); return true; }
            return false;
        })()
    """)
end

"""Select an option in a dropdown by partial text match."""
function select_option_containing(win, selector, text)
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
# Test Runner
# ─────────────────────────────────────────────────────────────────────────────

"""Handle kernel selection dialog if present."""
function handle_kernel_dialog!(win)
    sleep(2)

    if has_text(win, "Select Kernel")
        @info "Selecting Julia $JULIA_VERSION_STR kernel..."
        # Select kernel matching current Julia version (e.g., "Julia 1.12")
        select_option_containing(win, ".jp-Dialog select", JULIA_VERSION_STR)
        sleep(0.5)
        click_selector(win, ".jp-Dialog button.jp-mod-accept")
        sleep(2)
        return true
    end
    false
end

"""Wait for kernel to be idle."""
function wait_for_idle_kernel(win; timeout=60)
    deadline = time() + timeout
    while time() < deadline
        if has_text(win, "Idle")
            return true
        end
        sleep(1)
    end
    false
end

"""Run all cells in the notebook."""
function run_all_cells!(win)
    # Click the "Restart kernel and run all cells" button
    click_selector(win, "button[title='Restart the kernel and run all cells']")
    sleep(1)

    # Confirm the restart dialog if it appears
    if has_text(win, "Restart Kernel")
        click_selector(win, ".jp-Dialog button.jp-mod-accept")
        sleep(1)
    end
end

"""Poll for Bonito success marker."""
function wait_for_bonito_output(win)
    for i in 1:MAX_POLLS
        if has_text(win, "BONITO_TEST_SUCCESS")
            return true
        end
        @info "Waiting for output... ($i/$MAX_POLLS)"
        sleep(POLL_INTERVAL)
    end
    false
end

function test_jupyterlab(app)
    @info "Testing JupyterLab..."
    win = nothing
    try
        # Open the pre-made test notebook directly
        url = "http://localhost:$PORT/lab/tree/$NOTEBOOK_NAME"
        win = Electron.Window(app, URI(url))
        sleep(5)  # Wait for page load

        # Handle kernel selection
        handle_kernel_dialog!(win)

        # Wait for kernel to be ready
        if !wait_for_idle_kernel(win; timeout=30)
            @warn "Kernel didn't become idle, continuing anyway..."
        end

        @info "Running all cells..."
        run_all_cells!(win)

        if wait_for_bonito_output(win)
            @info "JupyterLab test PASSED ✓"
            return true
        end

        @error "Timeout waiting for BONITO_TEST_SUCCESS"
        return false
    catch e
        @error "JupyterLab test failed" exception=(e, catch_backtrace())
        return false
    finally
        !isnothing(win) && close(win)
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

function main()
    # Verify test notebook exists
    notebook_path = joinpath(TEST_DIR, NOTEBOOK_NAME)
    isfile(notebook_path) || error("Test notebook not found: $notebook_path")

    # Install kernel
    @info "Installing IJulia kernel..."
    IJulia.installkernel("Julia")

    jupyter = find_jupyter()
    @info "Using: $jupyter"

    # Start server
    proc = start_server(jupyter)
    app = Electron.Application()

    passed = false
    try
        wait_for_server()
        passed = test_jupyterlab(app)
    finally
        close(app)
        kill(proc)
    end

    println("\n", "="^50)
    println("RESULT: ", passed ? "✓ PASSED" : "✗ FAILED")
    println("="^50)

    passed || error("Test failed")
end

"""Run Jupyter smoke test, returning true if it passes."""
function run_jupyter_tests()
    main()
    return true
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
