# Announcing Bonito 5.0

Bonito 5.0 is here — and it's the biggest release since the package was renamed from JSServe. This version rebuilds large parts of the foundation (networking, sessions, asset serving) while adding the features that make Bonito a complete toolkit for building interactive web UIs, dashboards **and** documentation in pure Julia.

Here are the highlights.

## A new, fully Bonito-powered documentation site

The site you're reading right now is built with Bonito itself. The new `DocumenterBonito` writer plugs into [Documenter.jl](https://documenter.juliadocs.org/) and renders the whole site — landing page, sidebar, search, version switcher and this blog — as Bonito DOM, styled after VitePress with first-class light/dark themes.

The best part: interactive examples are rendered **inline and statically**. The widgets, plots and apps in the docs are real Bonito apps exported to static HTML, so they stay interactive without a running Julia server.

```julia
using Bonito

App() do
    s = Slider(1:100)
    value = DOM.div(s.value)
    return DOM.div(s, value)
end
```

Pointing your own package's docs at it is a one-liner in `make.jl`:

```julia
using Documenter, Bonito

makedocs(
    sitename = "MyPackage",
    format = Bonito.DocumenterBonito(),
)
```

## HTTP/2 under the hood

Bonito 5 moves to HTTP.jl 2.x. The server now speaks HTTP/2, multiplexing requests and WebSocket traffic over a single connection, which improves server→client throughput noticeably for app-heavy pages. The WebSocket upgrade is handled inline, so a single port serves assets, pages and the live connection.

## A composable handler & authentication system

Apps and routes can now be wrapped with composable handlers — think middleware — for authentication, rate limiting or custom logic. For example, `ProtectedRoute` adds HTTP Basic Authentication with password hashing and rate limiting to any app or static folder:

```julia
using Bonito

server = Server("127.0.0.1", 8081)
admin = App(() -> DOM.h1("Admin Panel"))
protected = ProtectedRoute(admin, SingleUser("admin", "secret"))
route!(server, "/admin" => protected)
```

`SingleUser` covers simple cases, but the `AbstractPasswordStore` interface lets you back authentication with a database or any other source by implementing a single method. Handlers compose, so building a protected, rate-limited, statically-served site is just a matter of stacking them. This work was made possible by an investment from the [Sovereign Tech Agency](https://www.sovereign.tech).

## Remote apps

You can now drive a Bonito app running in one Julia process from another — handy for embedding live apps into separate servers, notebooks or tooling without colocating all the code in a single process.

## A cleaner session & asset lifecycle

Under the hood, the session model was split into a `RootSession` and per-render sub-sessions, removing a whole class of lifecycle races around connect/close and freeing of observables. Asset serving was rewritten around explicit reference counting (no more finalizer-on-lock footguns), and now supports HTTP range requests for media.

## Dark-mode-aware widgets

Bonito's built-in widgets — buttons, sliders, dropdowns, tables, range sliders — now follow a small set of `--bonito-widget-*` CSS variables, and ship a default mapping keyed off `prefers-color-scheme`. Standalone apps follow the operating system's light/dark setting automatically, and a host page (like these docs) can re-theme every widget by redefining a handful of variables.

## Getting started

```julia
using Pkg
Pkg.add("Bonito")
```

Bonito 5 requires Julia 1.11 or newer. Head over to the [documentation](app.html) to dive in, and thanks to everyone who contributed, tested and gave feedback along the way!
