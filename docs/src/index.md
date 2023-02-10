`JSServe.jl` is a pretty simple package allowing to render HTML and serve it from within Julia and build up a communication bridge with the Browser. This allows to combine any of your Julia applications with libraries like [WGLMakie](https://docs.makie.org/dev/documentation/backends/wglmakie/index.html#export) and create interactive Dashboards like this:

![dashboard](https://user-images.githubusercontent.com/1010467/214651671-2f8174b6-48ab-4627-b15f-e19c35042faf.gif)

JSServe is tightly integrated with WGLMakie, which makes them a great pair for high performance, interactive visualizations.
If performance is not a high priority, many other plotting/visualization libraries which overload the Julia display system should work with `JSServe.jl` as well.

`JSServe.jl` itself tries to stay out of major choices like the HTML/CSS/Javascript framework to use for creating UIs and Dashboards.

It uses plain HTML widgets for UI elements where it can, and only to give some base convenience, there is `JSServe.TailwindDashboard` which gives the basic JSServe widgets some nicer look and make it a bit easier to construct complex layouts.

As you can see in `JSServe/src/tailwind-dashboard.jl`, it's just a thin wrapper around the basic `JSServe.jl` widgets, which gives them some class(es) to style them via [TailwindCSS](https://tailwindcss.com/).
Anyone can do this with their own CSS or HTML/Javascript framework, which should help to create a rich ecosystem of extensions around `JSServe.jl`.

## Quickstart

```@setup 1
using JSServe
JSServe.Page()
```

At the core of JSServe you have `DOM` to create any HTML tag, `js"..."` to run Javascript, and `App` to wrap your creation and serve it anywhere:

```@example 1
using JSServe
app = App() do
    return DOM.div(DOM.h1("hello world"), js"""console.log('hello world')""")
end
```

App has three main signatures:
```julia
# The main signatures, all other signatures will end up calling:
App((session, request) -> DOM.div(...))
# Convenience constructors:
App((session::Session) -> DOM.div(...))
App((request::HTTP.Request) -> DOM.div(...))
App(() -> DOM.div(...))
App(DOM.div(...))
```

`App` that don't use the `request` argument are considered `pure`, so they should always yield the same response when displayed/served.
If you depend on global state, or the app is not pure in some other way you have the following options:

```julia
App(pure=false) do
    return DOM.div(rand(10))
end
# Or bind a global
global some_observable = Observable("global hello world")
App() do session::Session
    bound_global = bind_global(session, some_observable)
    return DOM.div(bound_global)
end
```

For `Observables` this is especially important, since every time you display the app, listeners will get registered to it, that will just continue staying there until your Julia process gets closed.
`bind_global` prevents that by binding the observable to the life cycle of the session and cleaning up the state after the app isn't displayed anymore.
For other globals, this will just make the `App` unpure and disable any optimization relying on pureness.
If you serve the `App` via `Server`, be aware, that those globals will be shared with everyone visiting the page, so possibly by many users concurrently.

The app will be displayed by e.g. the VSCode plotpane, Jupyter/Pluto or any other framework that overloads the Julia display system for HTML display.
In the REPL or an environment without an HTML ready display, a browser should open to display it (enabled explicitly via `JSServe.browser_display()`), but one can also serve the App very easily:

```julia
server = Server(app, "0.0.0.0", 8080)
# This is the same as:
server = Server("0.0.0.0", 8080)
route!(server, "/" => app)
# So you can add many apps to one server, and even regexes are supported:
route!(server, r"*" => App(DOM.div("404, no content for this route")))
route!(server, "/some-app" => App(DOM.div("app")))
```

## Deploying

`JSServe.jl` wants to run everywhere, from Notebooks, IDEs, Electron, to being directly inserted into existing web pages.

![JSServe-wales](https://user-images.githubusercontent.com/1010467/214662497-a1a1c8e7-5f4d-4e57-b129-fdcc227253ca.gif)

Find out more about the different ways to serve your apps in [Deployment](@ref).
