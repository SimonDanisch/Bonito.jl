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

run_js(win, code::String) = try Electron.run(win, code) catch; nothing end

function has_text(win, text)
    escaped = replace(text, "'" => "\\'")
    run_js(win, "document.body.innerText.includes('$escaped')") === true
end

function click_selector(win, selector)
    run_js(win, "(function(){ const el = document.querySelector('$selector'); if(el){el.click(); return true} return false })()")
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

function get_cell_prompt(win)
    result = run_js(win, "(function(){ const p = document.querySelector('.jp-InputPrompt'); return p ? p.textContent.trim() : '' })()")
    something(result, "")
end

function trigger_cell_run!(win)
    run_js(win, """
        (function() {
            const cell = document.querySelector('.jp-Cell');
            if (cell) { cell.click(); cell.focus(); }

            const el = document.querySelector('[title*="Run this cell"]');
            if (el) {
                const btn = el.querySelector('button') || el;
                const rect = btn.getBoundingClientRect();
                ['mousedown', 'mouseup', 'click'].forEach(type => {
                    btn.dispatchEvent(new MouseEvent(type, {
                        bubbles: true, cancelable: true, view: window,
                        clientX: rect.left + rect.width/2, clientY: rect.top + rect.height/2
                    }));
                });
                btn.click();
            }

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

function run_cell!(win; max_retries=5, retry_delay=2)
    for attempt in 1:max_retries
        trigger_cell_run!(win)
        sleep(retry_delay)
        prompt = get_cell_prompt(win)
        if occursin(r"\[\*\]:", prompt) || occursin(r"\[\d+\]:", prompt)
            @info "Cell running (attempt $attempt)"
            return true
        end
    end
    @warn "Cell execution not detected after $max_retries attempts"
    false
end

function find_marker(win, marker)
    run_js(win, """
        (function() {
            if (document.body.innerText.includes('$marker')) return true;
            for (const out of document.querySelectorAll('.jp-OutputArea-output')) {
                if (out.innerText?.includes('$marker')) return true;
                for (const iframe of out.querySelectorAll('iframe')) {
                    try { if (iframe.contentDocument?.body?.innerText?.includes('$marker')) return true; } catch(e) {}
                }
            }
            for (const iframe of document.querySelectorAll('iframe')) {
                try { if (iframe.contentDocument?.body?.innerText?.includes('$marker')) return true; } catch(e) {}
            }
            return false;
        })()
    """) === true
end

function wait_for_output(win, token)
    marker = "BONITO_TEST_SUCCESS_$token"
    for i in 1:MAX_POLLS
        find_marker(win, marker) && return true
        prompt = get_cell_prompt(win)
        status = occursin("[*]:", prompt) ? "running" : occursin(r"\[\d+\]:", prompt) ? "finished" : prompt
        @info "Waiting for output... ($i/$MAX_POLLS) [$status]"
        sleep(POLL_INTERVAL)
    end
    false
end

# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

if !@isdefined(ELECTRON_OPTIONS)
    const ELECTRON_OPTIONS = Dict{String,Any}("show" => false, "focusOnWebView" => false)
end

const CI_ELECTRON_FLAGS = ["--no-sandbox", "--disable-gpu", "--disable-dev-shm-usage", "--disable-software-rasterizer"]

function run_test(jupyter)
    token = randstring(12)
    write(TOKEN_FILE, token)
    @info "Test token: $token"

    electron_args = haskey(ENV, "CI") ? CI_ELECTRON_FLAGS : String[]
    app = Electron.Application(; additional_electron_args=electron_args)
    proc = start_server(jupyter)

    try
        wait_for_server()
        win = Electron.Window(app, URI("http://localhost:$PORT/lab/tree/$NOTEBOOK_NAME"); options=ELECTRON_OPTIONS)
        sleep(5)

        handle_kernel_dialog!(win)
        wait_for_idle_kernel(win) || @warn "Kernel not idle, continuing..."

        @info "Running cell..."
        run_cell!(win) || @warn "Cell may not have started"

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

function run_jupyter_tests()
    isfile(joinpath(TEST_DIR, NOTEBOOK_NAME)) || error("Test notebook not found")
    @info "Installing IJulia kernel..."
    IJulia.installkernel("Julia")
    jupyter = find_jupyter()
    @info "Using: $jupyter"
    run_test(jupyter)
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
