![](dashi.png)

[Dashi (出汁, だし)](https://en.wikipedia.org/wiki/Dashi) is a family of stocks used in Japanese cuisine.
It's simple, but acts as a great flavor enhancer for everything you serve it with.
`Dashi.jl` aims to do just that for interactive visualizations.
On it's own `Dashi.jl` is a pretty simple package allowing to render HTML and serve it from within Julia and build up a communication bridge with the Browser. This allows to combine any of your Julia applications with libraries like [WGLMakie](https://docs.makie.org/dev/documentation/backends/wglmakie/index.html#export) and create interactive Dashboards like this:

![dashboard](https://user-images.githubusercontent.com/1010467/214651671-2f8174b6-48ab-4627-b15f-e19c35042faf.gif)

Dashi is tightly integrated with WGLMakie, which makes them a great pair for high performance, interactive visualizations.
If performance is not a high priority, many other plotting/visualization libraries which overload the Julia display system should work with `Dashi.jl` as well.

`Dashi.jl` itself is very un-opiniated and tries to stay out of major choices like the HTML/CSS/Javascript framework to use for creating UIs and Dashboards.

It uses plain HTML widgets for UI elements where it can, and only to give some base convenience, there is `Dashi.TailwindDashboard` which gives the basic JSServe widgets some nicer look and make it a bit easier to construct complex layouts.

As you can see in `Dashi/src/tailwind-dashboard.jl`, it's just a thin wrapper around the basic `Dashi.jl` widgets, which gives them some class(es) to style them via [TailwindCSS](https://tailwindcss.com/).
Anyone can do this with their own CSS or HTML/Javascript framework, which should help to create a rich ecosystem of extensions around `Dashi.jl`.

## Quickstart

```@setup 1
using Dashi
Dashi.Page()
```

At the core of Dashi you have `DOM` to create any HTML tag, `js"..."` to run Javascript, and `App` to wrap your creation and serve it anywhere:

```@example 1
using Dashi
App() do
    return DOM.div(DOM.h1("hello world"), js"""console.log('hello world')""")
end
```

## Deploying

`Dashi.jl` wants to run everywhere, from Notebooks, IDEs, Electron, to being directly inserted into existing web pages.

![dashi-wales](https://user-images.githubusercontent.com/1010467/214662497-a1a1c8e7-5f4d-4e57-b129-fdcc227253ca.gif)

Find out more about the different ways to serve your apps in [Deployment](@ref).
