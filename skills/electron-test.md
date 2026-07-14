# Electron testing skill for Bonito apps

When invoked, drive a Bonito app inside an Electron window: open it, simulate user interactions, assert on the live DOM, capture console output, and take screenshots. Works against any Bonito `App`. The user's prompt usually names the target — a function that returns a `Bonito.App`, or a `Bonito.Server` URL.

If the target isn't obvious, ask the user before opening anything. Otherwise: open, exercise, assert, screenshot, report. Use `julia_eval` for everything (env_path = the project root the user is in).

---

## Pattern reference

### Opening a Bonito app in Electron

```julia
using Bonito

# Headless-friendly options. Drop `show=>false` if you want the window visible.
opts = Dict{String,Any}("show" => false, "focusOnWebView" => false,
                        "width" => 1280, "height" => 800)
disp = Bonito.use_electron_display(; options = opts, devtools = false)

app  = some_bonito_app(...)               # any Bonito.App
display(disp, app)                        # blocks until the WS handshake completes
session = app.session[]                   # the live Bonito.Session
```

`display(disp, app)` navigates the Electron window to the app's URL and blocks until the Bonito session is fully open, so subsequent `run`/`evaljs_value` calls are safe.

If your target is already a running `Bonito.Server` (e.g. you started it elsewhere), point the existing window at its URL instead of `display`-ing an App:

```julia
using Electron: load, URI
load(disp.window.window, URI(Bonito.online_url(srv, "")))
sleep(2)   # let the WS handshake settle
```

`Electron.load(win, uri)` is the proper navigation API — it goes through the same `loadURL` IPC the framework uses internally. Don't reach for `run(disp.window, "window.location.href = …")`; that bypasses Electron's lifecycle hooks and can leave the window in an inconsistent state for subsequent IPC.

### Running JS and reading return values

Two APIs — pick based on what you need:

```julia
# evaljs_value: round-trips through Bonito's WS channel; returns any JSON-able value
result = Bonito.evaljs_value(session, js"document.querySelector('.my-class') !== null")

# run(window, code): calls directly into the Electron renderer via IPC (no WS hop);
# faster, supports full DOM API, returns the synchronous return value of `code`.
run(disp.window, "document.querySelectorAll('.todo-row').length")
run(disp.window, "document.querySelector('input[name=title]').value")
run(disp.window, "document.querySelector('button.submit').disabled")
```

Prefer `run(disp.window, …)` for tests — it's faster and doesn't depend on the WS being healthy.

### Clicking and typing

```julia
run(disp.window, "document.querySelector('button.submit').click()")

# Set an input/textarea value and fire `input` so any oninput handler runs.
# After the dispatch, sleep briefly so Bonito's WS delivers the observable
# update to Julia before any Julia-side assertion that depends on it.
run(disp.window, """
    const ta = document.querySelector('textarea.body');
    ta.value = 'hello';
    ta.dispatchEvent(new Event('input', { bubbles: true }));
""")
sleep(0.5)
```

For checkboxes, `<select>`, etc., set the property and dispatch `change` instead of `input`.

### Capturing console logs

Pass Chromium's `--enable-logging --log-file=PATH` switches when launching the Electron app — every renderer `console.log/warn/error` and uncaught error is appended to the file with no JS injection or event-listener plumbing required.

```julia
log_path = tempname() * ".log"
disp = Bonito.use_electron_display(;
    options = opts,
    electron_args = String[
        "--enable-logging",        # write Chromium logs (incl. renderer console)
        "--log-file=$log_path",    # to this file (default: stderr)
        "--v=0",                   # 0=info+, raise for verbose. -1 silences info.
    ],
)
display(disp, target_app)
# … run the test …
logs = isfile(log_path) ? read(log_path, String) : ""
@assert !occursin("ERROR:", logs)  "Chromium reported errors:\n$logs"
```

The file format is one line per log entry, prefixed with timestamp + severity (`INFO`, `WARNING`, `ERROR`). `grep` / `occursin` on the contents is usually enough; for structured access, parse with a regex on the prefix. The file is written incrementally — read it any time during the test, no need to wait for shutdown.

If you only want to react to errors mid-test, poll `filesize(log_path)` rather than re-reading the whole file.

### Taking a screenshot

`webContents.capturePage()` is only available from Electron's main process, so it's invoked via `disp.window.app` (the `Application`), not the window. Write the PNG to `tempdir()` and return the path — Claude Code reads/displays PNG paths as images via the Read tool.

```julia
function screenshot(disp; timeout::Real = 5)
    win_id = disp.window.window.id
    path   = joinpath(tempdir(), "electron-shot-$(time_ns()).png")
    flag   = path * ".done"   # signal file written *after* the PNG, atomically detectable
    run(disp.window.app, """
        const win = electron.BrowserWindow.fromId($win_id);
        win.webContents.capturePage().then(img => {
            require('fs').writeFileSync('$path', img.toPNG());
            require('fs').writeFileSync('$flag', '1');
        });
        null
    """)
    let t = time()
        while !isfile(flag) && time() - t < timeout
            sleep(0.05)
        end
    end
    isfile(path) || error("screenshot timed out after $(timeout)s")
    rm(flag; force = true)
    return path
end

# Usage — return / show the path; do NOT base64-encode or println the bytes.
shot = screenshot(disp)
@info "screenshot" path=shot
```

The path can be passed back to the user (or to a follow-up `Read`) as an image. Don't base64-print the PNG into the chat — it overflows the response budget; a `tempdir()` path is the same outcome with none of the cost.

### Cleanup

```julia
close(disp)   # closes the Electron window
close(srv)    # if you started a Bonito.Server yourself
```

`close` should return cleanly. Don't wrap it in a bare `try/catch …  end` to hush it — a throw from `close` is a real bug worth fixing (or at least surfacing with `@warn`), not swallowing.

---

## Test loop shape

The recipe for any test:

```julia
log_path = tempname() * ".log"
disp = Bonito.use_electron_display(;
    options = opts, devtools = false,
    electron_args = String["--enable-logging", "--log-file=$log_path", "--v=0"],
)
display(disp, target_app)
sleep(1)                              # let initial render settle

# Assertions, one per `run(...)` call. Compare the value Julia-side.
@assert run(disp.window, "document.querySelector('.app') !== null")  "missing root"
@assert run(disp.window, "document.querySelectorAll('.row').length") == 0  "expected empty"

# Interact
run(disp.window, "document.querySelector('button.add').click()")
sleep(0.3)                            # let observable round-trip back to JS

# Assert again
@assert run(disp.window, "document.querySelectorAll('.row').length") == 1  "row not added"

# Capture artefacts
shot = screenshot(disp)
logs = isfile(log_path) ? read(log_path, String) : ""
@assert !occursin("ERROR:", logs) "renderer reported errors:\n$logs"

close(disp)
@info "test passed" screenshot=shot log=log_path
```

When the user asks "test X", produce a checklist of assertions appropriate to the app, run them in order, take a screenshot at meaningful points (initial load, after a key interaction, on failure), and report **pass/fail with the actual value observed** plus the screenshot path. If anything fails, print the captured console + errors.

---

## Notes

- **Don't `display(disp, app)` twice in the same window** — the second call may race the first's WS teardown. Open a fresh `use_electron_display` if you need a clean slate.
- **`use_electron_display` reuses one Application across windows.** Two simultaneous browser sessions for the same app need two `Application` instances (`Electron.Application(...)` directly), not two `use_electron_display` calls.
- **For long-running JS handlers you trigger** (e.g. clicking something that spawns an `@async` chain server-side), poll for the expected DOM change rather than `sleep`-ing a fixed time. `sleep(0.5)` is fine for sub-second observable round-trips; longer waits are a smell.
- **`run(disp.window, ...)` returns a `JSON.Object{String,Any}` for object literals** — index with string keys, not symbols, in Julia.
