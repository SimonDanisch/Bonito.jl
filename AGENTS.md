# Bonito best practices

How to write Bonito widgets and apps. Distilled from the reviewed code in
Bonito core and BonitoBook (`MonacoEditor` / `EvalEditor` / `CellEditor` /
`FileEditor` / `Book` are the reference implementations). Code-style basics
(naming, no `_` prefixes, multiple dispatch, UPPERCASE consts) live in the
project-level CONVENTIONS.md; this file is about *architecture*: how state,
rendering, and Julia↔JS communication should be organized.

Related developer docs:
- [`skills/electron-test.md`](skills/electron-test.md) — drive a Bonito app in an
  Electron window (open, interact, assert on the DOM, capture logs/screenshots).
- [`js_dependencies/STABILITY_FIXES.md`](js_dependencies/STABILITY_FIXES.md) — the
  JS client stability fixes (findings `J1`–`J15`); the `J#` tags in the JS source
  point here, and `test/reconnect.jl` exercises the reconnect cluster.

## 1. A widget is a struct of Observables

A widget is a plain Julia struct whose mutable state is `Observable`s.
The constructor builds the observables and wires internal listeners.
`Bonito.jsrender(session, widget)` turns it into DOM. All behavior is
exposed as Julia functions taking the widget:

```julia
struct FileEditor
    editor::EvalEditor
    current_file::Observable{String}
end

function open_file!(editor::FileEditor, filepath::String; line::Union{Int,Nothing}=nothing)
    editor.current_file[] = filepath
    set_source!(editor.editor, read(filepath, String))
    isnothing(line) || send(editor.editor; type = "goto-line", line = line)
    toggle!(editor.editor; editor = true)
end
```

The consequences of this shape:

- **The widget is a value.** You can hold it in a field, pass it as an
  argument, compose it into a bigger widget (`CellEditor` wraps
  `EvalEditor` wraps `MonacoEditor`), and drive it from anywhere that has
  a reference — REPL included.
- **Features are functions, not JS snippets.** "Open this file in the
  editor" is `open_file!(editor, path)`, not an `evaljs` that pokes the
  DOM. If you find yourself writing `Bonito.evaljs(session,
  js"window.something.do(...)")` to trigger app behavior from Julia, the
  design is wrong — the behavior belongs on a widget you can call.
- **Rendering is a pure consequence of state.** `jsrender` reads the
  observables and builds DOM that *reacts* to them. It must be safe to
  render the same widget into a fresh session after a reload and end up
  in the same visual state.

Construct observables in the constructor, not in `jsrender`: `jsrender`
runs once per session/tab, so any state created there is per-tab and
silently diverges between tabs. Per-tab state is occasionally right (a
local "is this panel expanded here" toggle) — make that an explicit,
commented choice.

## 2. State ownership: app object down, never globals up

An application has one root object that owns everything (BonitoBook's
`Book`): the widget instances, the domain state, the long-lived
observables. Sub-components receive what they need **as constructor /
function arguments**. Anything you need later is reachable through the
object graph:

```julia
fe = get_file_editor(book)        # book.widgets["file_editor"]
open_file!(fe, path; line = 42)
```

Hard rules:

- **No module-level mutable state for app/widget wiring.** No
  `const REGISTRY = Dict{Session,Foo}()`, no `Ref` caches that exist only
  to avoid passing an argument three layers down. If a function needs the
  editor, it takes the editor (or the app object) as an argument. Globals
  are for static config tables (`const TOOL_ICONS = Dict(...)`), never
  for reaching live objects.
- **No `window.*` namespaces on the JS side either.** A JS-global
  controller (`window._myController.do(...)`) is the JS spelling of the
  same mistake. State lives in JS class instances that were *given* their
  DOM nodes and observables (§4); Julia reaches them through observables,
  not through `evaljs` + global lookup.
- If two distant components must talk, the *app object* mediates: it owns
  both, so it can wire `on(a.something) do ... b ... end` at construction
  time. Distance in the DOM is irrelevant; distance in the object graph
  is what you design.

## 3. Julia ↔ JS communication

Three tiers — use the smallest one that fits:

**a) One value, one direction → a plain Observable.**

```julia
DOM.button("Save"; onclick = js"event => $(save_clicked).notify(true)")
on(session, save_clicked) do _
    save(book)
end
```

Julia → JS side effects use `onjs`:

```julia
onjs(session, button.content, js"x => $(button_dom).innerText = x")
```

**b) A stream of structured messages → one Observable{Dict} per direction
plus a message dispatcher.** This is the `EvalEditor` pattern:

```julia
struct EvalEditor
    js_to_julia::Observable{Dict{String,Any}}
    julia_to_js::Observable{Dict{String,Any}}
    ...
end

send(editor::EvalEditor; msg...) =
    editor.julia_to_js[] = Dict{String,Any}(string(k) => v for (k,v) in pairs(msg))

function process_message(editor::EvalEditor, message::Dict)
    if message["type"] == "new-source"
        ...
    elseif message["type"] == "run"
        run!(editor)
    elseif message["type"] == "multi"
        foreach(m -> process_message(editor, m), message["data"])
    else
        error("Unknown message type: $(message["type"])")
    end
end
```

Mirror the dispatcher in the JS class (`process_message(msg)` over
`julia_to_js.on(...)`). Batch bursts as one `multi` message. Unknown
message types are an `error`, not a silent fall-through — protocol drift
should be loud.

**c) Request/response (Julia asks JS for something) → message pair with a
`request_id`, plus `Bonito.wait_for`:**

```julia
send(editor; type = "capture-output", request_id = id)
status = Bonito.wait_for(timeout = 5.0) do
    msg = editor.capture_response[]
    msg isa AbstractDict && get(msg, "request_id", "") == id
end
```

What you should **not** see: stringly-typed events flowing through ad-hoc
`evaljs` calls; JS reading app state out of the DOM; two components
communicating via `document.querySelector` on each other's nodes.

## 4. JS belongs in ES6 modules, organized as classes

One `.js` file per concern, loaded once per package as a top-level const:

```julia
const Monaco = ES6Module(joinpath(@__DIR__, "javascript", "Monaco.js"))
```

`jsrender` hands the module class its DOM nodes and observables — *as
interpolated arguments, never via getElementById*:

```julia
return Bonito.jsrender(session, DOM.div(
    editor_div,
    js"""
    $(Monaco).then(mod => {
        const ed = new mod.EvalEditor(
            $(editor_div), $(output_div),
            $(editor.js_to_julia), $(editor.julia_to_js), $(editor.source));
        return ed.editor;   // a Promise — Bonito awaits it as mount-readiness
    })
    """))
```

On the JS side:

```js
export class EvalEditor {
    constructor(editor_div, output_div, js_to_julia, julia_to_js, source_obs) {
        this.editor_div = editor_div;          // state lives on `this`
        this.js_to_julia = js_to_julia;
        julia_to_js.on(msg => this.process_message(msg));
    }
    process_message(msg) { ... }               // mirrors the Julia dispatcher
}
```

Guidelines:

- **Classes hold instance state; modules hold pure helpers.** Exported
  functions (`toggle_elem`, `resize_to_lines`) are fine for stateless
  utilities. Anything with lifecycle is a class instance created by the
  widget's `jsrender`.
- **Return the readiness Promise** from the `$(Module).then(...)` block
  when the widget needs async setup — Bonito uses it to know when the
  component is actually up (and tests can await it).
- Document-level listeners: almost never page-global. In order of
  preference —

  1. **Scope them to the gesture.** Drag/move/up handlers only matter
     while the gesture runs: add on start, remove on end. An
     `AbortController` makes the teardown one line and the closures bind
     the right instance:

     ```js
     start_drag(e) {
         this.drag_abort = new AbortController();
         const { signal } = this.drag_abort;
         document.addEventListener("dragover", e => this.on_drag_over(e), { signal });
         document.addEventListener("drop",     e => this.on_drop(e),      { signal });
     }
     end_drag() { this.drag_abort?.abort(); }
     ```

     For pointer-based drags, `element.setPointerCapture(e.pointerId)`
     keeps events flowing to the element after the cursor leaves it —
     no document listeners at all.

  2. **Genuinely one-per-page behavior → ES6-module top level.** A module
     executes once per page, so top-level code *is* the once-guard.
     Instances register in a module-scope `Set`; the single listener
     dispatches to them; `dispose()` (wired to `Base.close(widget)`)
     deregisters.

  3. Lazy installation → a memoized module-scope `let installed = false`,
     private to the module.

  A `window._FLAG_SET` guard is the pattern to avoid: besides polluting
  `window`, the guarded listeners close over `this` of whichever instance
  ran setup *first* — later instances silently dispatch to (or get
  dropped by) the wrong object. (Its one excuse — the same helper file
  bundled into two different bundles gets two module scopes — is solved
  by not double-bundling shared helpers, not by a global.)
- External libs load inside the module (`import("https://cdn...")` at
  module scope, memoized). Deno bundles the module with its imports
  automatically; while iterating on an imported file, `Bonito.rebundle!`
  (or delete the `.bundled.js`) — edits to *imported* files don't bump
  the main file's mtime.
- Building HTML by string concatenation in JS (`innerHTML = `<div
  class=...>${escape(x)}...``) is a last resort for hot virtual-scroll
  paths. The default is: structure comes from Julia DOM, behavior from a
  JS class operating on interpolated nodes.

## 5. Reactive rendering

Bonito renders Observables, so derived views are `map`, not manual DOM
patching:

```julia
messages_display = map(chat.messages) do msgs
    DOM.div(msgs...; class = "chat-messages-container")
end
DOM.div(messages_display)   # re-renders ALL messages on every messages[] = ...
```

(Fine for a short list — but see the no-diffing caveat below before
putting anything growing or stateful behind one observable.)

- `DOM.div(obs)` works for any renderable observable content; numbers and
  strings get a fast in-place `innerText` path.
- A `Task` is renderable too: `DOM.div(@async expensive())` shows a
  spinner and swaps in the result.
- **Type-pinning gotcha:** `map(session, obs) do ...` infers the output
  Observable's type from the *first* result. If the hidden state returns
  `DOM.div()` and the visible state returns your widget struct, the
  update throws a convert `MethodError` at the worst moment. Return one
  consistent type (e.g. always the widget, let its `jsrender` handle the
  empty state), or construct `Observable{Any}` explicitly.
- **Observable content does NOT diff.** Every update to a rendered
  `Observable` (or a `map` returning DOM) tears down the previous
  sub-session and re-renders the whole subtree — there is no virtual-DOM
  diffing. For a handful of bubbles that's fine; for a chat history or a
  cell list it means every appended item re-mounts *everything* (Monaco
  instances, WebGL canvases, scroll state — all lost), and update cost
  grows with total size, not change size. Keep reactively-rendered
  observables SMALL: one per item, or one per bounded region, never "the
  whole list".
- For collections, use `Bonito.KeyedList` (or an equivalent
  stable-identity pattern): it diffs an `Observable{Vector{T}}` against
  the previously shipped keys and emits minimal insert/remove/move ops —
  survivors keep their DOM and JS bindings. The contract that makes it
  work: items must be *stable instances* (cache widgets in a `Dict` keyed
  by their natural id and re-emit the same instances each render), with a
  `key` function deriving that identity. The second escape hatch is
  `dom_in_js` (below) for surgical single-spot updates. This area is a
  known Bonito weak spot — expect it to improve, and prefer designs where
  item identity is explicit so they can ride those improvements.
- `attribute = obs` works for DOM attributes (`value = tf.value`,
  `disabled = chat.is_processing`) — prefer it over an `onjs` that sets
  the attribute manually.
- `Bonito.dom_in_js` (render Julia content, hand the resulting DOM node
  to a JS function that places it) is the *other* escape hatch from the
  no-diffing problem: a precise, surgical update of one spot in the DOM
  without re-rendering anything around it. Reach for it when the
  placement is JS-owned (a virtual scroller deciding where a
  lazily-rendered body mounts) or when an observable re-render would
  tear down too much around the change. For a panel you own whose whole
  content swaps as a unit, the default is still an `Observable` content
  slot — it's the same cost there and the API stays declarative.

## 6. Lifecycle and sessions

- Use the session-scoped listener forms — `on(f, session, obs)`,
  `onany(f, session, obs...)`, `map(f, session, obs)` — for anything
  wired during `jsrender`. They deregister when the session closes;
  the bare forms leak listeners into dead sessions.
- Widgets that own observables implement `Base.close(widget)` and clear
  them (`Observables.clear`), composing downward (`close(cell)` closes
  its `EvalEditor`).
- `session.on_close` is the hook for cleanup that isn't listener-shaped.
- Handlers registered during a *sub*-session render (a `map(session,…)`
  body, a per-message render) belong to that sub-session, so they're
  freed when the content is replaced — that's the point. Register on the
  long-lived parent only what must outlive re-renders, and know which one
  you're doing.

## 7. Styling

- `Bonito.Styles` + `CSS` for everything; no `style = "..."` strings.
  Component-scoped styles are part of the component's DOM (Bonito
  deduplicates them per page):

  ```julia
  return Bonito.jsrender(session, DOM.div(EditorStyles, container))
  ```
- Theme via CSS variables, defined once at app level with Julia-side
  parameters (BonitoBook's `generate_style(book; spacing_sm="0.5rem",
  z_modal="1000", ...)` emitting `--bg-primary` etc.). Component CSS
  references `var(--border-primary)` — components don't hardcode colors.
- Class names are namespaced per package (`bonitobook-button`,
  `cell-editor`) so two Bonito apps can coexist on a page.

## 8. App composition

The app constructor builds the object graph; rendering happens last:

```julia
book = Book(file)                          # owns cells, runner, widgets, observables
fe   = TabbedFileEditor(files)             # widgets constructed up front…
book.widgets["file_editor"] = fe           # …owned by the app object
on(file_tabs.current_file) do path         # cross-widget wiring at construction
    open_file!(file_editor, path)
end
App(...) do session; jsrender(session, book); end
```

Event flow is always the same loop: DOM event → `obs.notify` → Julia
`on` handler → mutate app/widget state → reactive DOM updates. If you can
trace a feature through that loop, it's structured right. If a feature
needs an `evaljs` mid-loop to *make something happen* (rather than to
read a value back), a widget API is missing.

## 9. Anti-pattern checklist

Concrete smells, each with the fix:

| Smell | Fix |
|---|---|
| `window._myThing = {...}` controller in a `js""` block | ES6 class instantiated with its nodes/observables; Julia talks via observables |
| `document.getElementById('other-widget-mount')` across components | Interpolate the node (`$(div)`) or let the app object wire the two widgets |
| `const PANES = Dict{Session,Pane}()` module global | The pane is a field of the app/widget that needs it; pass it down |
| `Bonito.evaljs(session, js"...do the thing...")` as an API | A Julia function on the widget (`open_file!`, `toggle!`) that sends a message/sets an observable |
| `dom_in_js` to replace a panel's content | The panel renders an `Observable` content slot; setting it is the API |
| Inline `style="..."` | `Styles`/`CSS`, themed via `var(--...)` |
| One 3000-line JS file of event-soup helpers | One ES6 module per concern; classes for stateful parts |
| `map(session, obs)` whose branches return different types | One renderable type for all states, or explicit `Observable{Any}` |
| One observable wrapping a whole growing list (chat history, cell list) | `Bonito.KeyedList` with stable item instances, or per-item observables — observable re-render does not diff |
| Bare `on(obs)` inside `jsrender` | `on(f, session, obs)` so it dies with the session |
| `window._X_SET` flag guarding one-time listeners | Gesture-scoped listeners (`AbortController` / `setPointerCapture`), or module-top-level install with an instance registry |
| Silent `catch` around a JS bridge call | Propagate or surface in the UI; a dead bridge must be loud |
