`JSServe.jl` is a pretty simple package allowing you to render HTML and serve it from within Julia and build up a communication bridge with the Browser. This allows to combine any of your Julia applications with libraries like [WGLMakie](https://docs.makie.org/dev/documentation/backends/wglmakie/index.html#export) and create interactive Dashboards like this:

![dashboard](https://user-images.githubusercontent.com/1010467/214651671-2f8174b6-48ab-4627-b15f-e19c35042faf.gif)

JSServe is tightly integrated with WGLMakie, which makes them a great pair for high performance, interactive visualizations.
If performance is not a high priority, many other plotting/visualization libraries which overload the Julia display system should work with `JSServe.jl` as well.

`JSServe.jl` itself tries to stay out of major choices like the HTML/CSS/Javascript framework to use for creating UIs and Dashboards. Instead, it allows to create modular components and makes it easy to use any CSS/Javascript library.

It uses plain HTML widgets for UI elements where it can, and there are a few styleable components like `Card`, `Grid`, `Row`, `Col` to make it easy to create some more complex dashboards out of the box.

If you look at the source of those components, one will see that they're very simple and easy to create, which should help to create a rich ecosystem of extensions around `JSServe.jl`.
Read more about it in [Components](@ref).

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

The app will be displayed by e.g. the VSCode plot pane, Jupyter/Pluto or any other framework that overloads the Julia display system for HTML display.
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

## Easy integration with existing JS + CSS libraries

It's quite easy to integrate existing Libraries into your JSServe App:

```@example 1
App() do
    js = ES6Module("https://esm.sh/v133/leaflet@1.9.4/es2022/leaflet.mjs")
    css = Asset("https://unpkg.com/leaflet@1.9.4/dist/leaflet.css")
    map_div = DOM.div(id="map"; style="height: 300px; width: 100%")
    return DOM.div(
        css, map_div,
        js"""
        $(js).then(L=> {
            const map = L.map('map').setView([51.505, -0.09], 13);
            L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png').addTo(map);
        })
        """
    )
end
```

Read more about wrapping libraries in [Javascript](@ref).

## Deploying

`JSServe.jl` wants to run everywhere, from Notebooks, IDEs, Electron, to being directly inserted into existing web pages.

![JSServe-wales](https://user-images.githubusercontent.com/1010467/214662497-a1a1c8e7-5f4d-4e57-b129-fdcc227253ca.gif)

Find out more about the different ways to serve your apps in [Deployment](@ref).
