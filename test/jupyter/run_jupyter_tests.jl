#=
Jupyter Smoke Tests for Bonito

Tests Bonito rendering in JupyterLab and Jupyter Notebook using Playwright via PyCall.
Playwright is auto-installed via conda-forge if not present.

Usage: julia --project=@. test/jupyter/run_jupyter_tests.jl
=#

using IJulia, PyCall, HTTP

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

const PORTS = (lab=8888, notebook=8889)
const TIMEOUT_MS = 30_000
const POLL_INTERVAL = 5
const MAX_POLLS = 6

const JULIA_KERNEL = "Julia $(VERSION.major).$(VERSION.minor)"
const BONITO_ROOT = dirname(dirname(@__DIR__))

const TEST_CODE = """
using Pkg
Pkg.activate()
Pkg.develop(path="$BONITO_ROOT")
using Bonito
App() do session
    Bonito.DOM.div("BONITO_TEST_SUCCESS"; id="bonito-test-output")
end |> display
"""

# ─────────────────────────────────────────────────────────────────────────────
# Infrastructure
# ─────────────────────────────────────────────────────────────────────────────

"""Return Playwright sync API, installing via conda if needed."""
get_playwright() = pyimport_conda("playwright.sync_api", "playwright", "conda-forge")

"""Find jupyter executable via IJulia or PATH."""
function find_jupyter()
    # Try IJulia's conda jupyter first
    path = IJulia.find_jupyter_subcommand("lab")
    !isnothing(path) && !isempty(path) && isfile(first(path)) && return first(path)
    # Fall back to system jupyter
    jupyter = Sys.which("jupyter")
    !isnothing(jupyter) && return jupyter
    error("Could not find jupyter executable")
end

"""Start a Jupyter server, returning the process handle."""
function start_server(jupyter, mode::Symbol, port)
    cmd = `$jupyter $mode --no-browser --port=$port --IdentityProvider.token=`
    run(pipeline(cmd; stdout=devnull, stderr=devnull); wait=false)
end

"""Block until server responds on port."""
function wait_for_server(port; timeout=60)
    deadline = time() + timeout
    while time() < deadline
        try
            r = HTTP.get("http://127.0.0.1:$port/api";
                connect_timeout=2, readtimeout=2, retry=false, status_exception=false)
            r.status == 200 && return
        catch; end
        sleep(1)
    end
    error("Server on port $port failed to start")
end

"""Install Playwright's Chromium browser if needed."""
function ensure_chromium()
    try run(`$(PyCall.pyprogramname) -m playwright install chromium`) catch; end
end

# ─────────────────────────────────────────────────────────────────────────────
# Page Helpers
# ─────────────────────────────────────────────────────────────────────────────

"""Handle kernel selection/error dialogs if present."""
function handle_kernel_dialogs!(page)
    # Dismiss error dialog first
    if page.get_by_text("Error Starting Kernel").count() > 0
        page.get_by_role("button", name="Ok").click()
        sleep(1)
    end
    # Select Julia kernel if prompted
    if page.get_by_text("Select Kernel").count() > 0
        @info "Selecting $JULIA_KERNEL kernel..."
        dialog = page.get_by_role("dialog")
        dialog.get_by_role("combobox").select_option(label=JULIA_KERNEL)
        dialog.get_by_role("button", name="Select").click()
        sleep(2)
    end
end

"""Execute code in the first notebook cell."""
function run_cell!(page, code)
    page.wait_for_selector("[role=textbox]"; timeout=TIMEOUT_MS)
    sleep(1)
    textbox = page.get_by_role("textbox").first
    textbox.click()
    page.keyboard.press("Control+a")
    textbox.fill(code)
    page.keyboard.press("Shift+Enter")
end

"""Poll for Bonito success marker, return true if found."""
function wait_for_bonito_output(page)
    for i in 1:MAX_POLLS
        sleep(POLL_INTERVAL)
        page.get_by_text("BONITO_TEST_SUCCESS").count() > 0 && return true
        @info "Waiting for output... ($i/$MAX_POLLS)"
    end
    false
end

# ─────────────────────────────────────────────────────────────────────────────
# Test Runners
# ─────────────────────────────────────────────────────────────────────────────

"""Run a test with browser lifecycle management."""
function with_browser(f, pw)
    browser = pw.chromium.launch(headless=true)
    try
        page = browser.new_page()
        page.set_default_timeout(TIMEOUT_MS)
        return f(page)
    finally
        browser.close()
    end
end

function test_jupyterlab(pw)
    @info "Testing JupyterLab..."
    with_browser(pw) do page
        page.goto("http://localhost:$(PORTS.lab)/lab")
        page.wait_for_load_state("networkidle")
        sleep(2)

        # Either select kernel from dialog or click launcher button
        if page.get_by_text("Select Kernel").count() > 0
            handle_kernel_dialogs!(page)
        else
            # Launcher button has duplicated kernel name: "Julia 1.12 Julia 1.12"
            page.get_by_role("button", name="$JULIA_KERNEL $JULIA_KERNEL").click()
            sleep(2)
            handle_kernel_dialogs!(page)  # May still get error dialog
        end

        run_cell!(page, TEST_CODE)
        @info "Running cell..."

        if wait_for_bonito_output(page)
            @info "JupyterLab test PASSED ✓"
            return true
        end
        error("Timeout waiting for BONITO_TEST_SUCCESS")
    end
end

function test_notebook(pw)
    @info "Testing Jupyter Notebook..."
    with_browser(pw) do page
        page.goto("http://localhost:$(PORTS.notebook)/notebooks/Untitled.ipynb")
        page.wait_for_load_state("networkidle")
        sleep(2)

        handle_kernel_dialogs!(page)

        run_cell!(page, TEST_CODE)
        @info "Running cell..."

        if wait_for_bonito_output(page)
            @info "Jupyter Notebook test PASSED ✓"
            return true
        end
        error("Timeout waiting for BONITO_TEST_SUCCESS")
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

function main()
    # Setup
    @info "Installing IJulia kernel for $JULIA_KERNEL..."
    IJulia.installkernel("Julia")

    playwright_api = get_playwright()
    ensure_chromium()
    pw = playwright_api.sync_playwright().start()

    jupyter = find_jupyter()
    @info "Using: $jupyter"

    # Start servers
    lab_proc = start_server(jupyter, :lab, PORTS.lab)
    notebook_proc = start_server(jupyter, :notebook, PORTS.notebook)

    results = Dict{String,Bool}()
    try
        wait_for_server(PORTS.lab)
        wait_for_server(PORTS.notebook)

        results["JupyterLab"] = try test_jupyterlab(pw) catch e
            @error "JupyterLab test failed" exception=(e, catch_backtrace())
            false
        end

        results["Notebook"] = try test_notebook(pw) catch e
            @error "Notebook test failed" exception=(e, catch_backtrace())
            false
        end
    finally
        pw.stop()
        kill(lab_proc)
        kill(notebook_proc)
    end

    # Report
    println("\n", "="^50)
    println("RESULTS:")
    for (name, passed) in sort(collect(results))
        println("  $name: ", passed ? "✓ PASSED" : "✗ FAILED")
    end
    println("="^50)

    all(values(results)) || error("Some tests failed")
end

"""Run all Jupyter smoke tests, returning true if all pass."""
function run_jupyter_tests()
    main()
    return true
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
