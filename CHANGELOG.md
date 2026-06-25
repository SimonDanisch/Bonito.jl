# Changelog

All notable changes to Bonito.jl are documented here. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project follows [semantic versioning](https://semver.org/).

## [5.0.0]

The biggest release since the package was renamed from JSServe. Most of the work went into networking, session handling, asset serving and serialization, making communication with the browser substantially faster and more stable. See the [release blog post](https://bonito.sh/dev/v5-release.html) for the full write-up and benchmarks.

### Breaking

- **Requires Julia 1.11** (was 1.10).
- **Now depends on HTTP.jl 2.4** (was 1.x). Any environment or downstream package that pins HTTP to 1.x must upgrade. Code touching HTTP/WebSocket internals through Bonito may need adjusting.
- **Session model rework.** `Session` was split into a `RootSession` (one per real connection) and lightweight per-render sub-sessions, and `SubConnection` was removed. Code that constructed `Session`/`SubConnection` directly, or dispatched on `Session{SubConnection}`, no longer compiles. Use the documented `App`/`Page` API; test for the connection root with the new `isroot(session)`.
- **`isready(session)` no longer force-closes the session on a recorded init/render error.** It still throws that error by default (`throw=true`) to surface the real cause, but now leaves the WebSocket open so the error reaches the browser through the reconnect indicator. The new `throw=false` keyword returns a pure connection-state check without consuming or raising a recorded error. Callers that want the old behavior must `close(session)` explicitly.

### Added

- New `Bonito.DocumenterBonito()` Documenter format: a VitePress-style, fully Bonito-rendered docs site (landing page, sidebar, search, version switcher and an experimental blog with RSS) with no extra static-site generator or Node build.
- `LoadingPage` is now exported.
- `KeyedList` for efficient keyed list rendering.
- Terminal/markdown rendering helpers: `RichText`, `TerminalOutput`, `ANSI_CSS`, `ansi_to_html`, `has_ansi_codes`, `append_html!`, `bonito_parser`, `commonmark_to_dom` (ANSI escapes + CommonMark in terminal output).
- Remote apps: drive an app running in one Julia process from another.
- Dark-mode-aware built-in widgets via `--bonito-widget-*` CSS variables with a `prefers-color-scheme` default mapping.
- HTTP asset server gained range requests for media, `Cache-Control` headers, automatic registration of interpolated ES6 modules, and precompile-time tracking of its source/bundle dependencies.

### Changed

- Object and asset lifetimes are managed with reference counting instead of finalizers (no more finalizers running inside locks).
- App rendering has a single error boundary: render and init errors are caught and surfaced through the reconnect indicator's `error[]` observable and a minimal error page, instead of taking down the session.
- Reactive wrappers no longer break `flex`/`grid` layout when an Observable sits in the middle of a layout.
- Testing and display run on [ElectronCall](https://github.com/IanButterworth/ElectronCall.jl) (the old Electron backend still works).
- Faster serialization via a reusable per-session pack buffer (`SessionIO`) and upstream MsgPack.jl improvements.

### Fixed

- Numerous connect/close and reconnect races, reconnect deadlocks and stale-error reconnects, and thread-safety issues across the session lifecycle.
- `port = 0` (ephemeral port) now works; `proxy_url` fixes.
- msgpack packing scratch buffers (`SessionIO`) are now pooled per session *tree* on the `RootSession` instead of allocated per `Session`. One buffer is checked out per in-flight message and returned afterwards, so idle memory is bounded by concurrency (≈1 buffer) rather than by sub-session count, and the re-entrant pack path no longer allocates a throwaway buffer. A buffer that a one-off large message (e.g. a WGLMakie scene) grew past 1 MiB is dropped back to a small buffer on return, so a long-lived session no longer pins tens of MB of idle packing scratch.

[5.0.0]: https://github.com/SimonDanisch/Bonito.jl/releases/tag/v5.0.0
