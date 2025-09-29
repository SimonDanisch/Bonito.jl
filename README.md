# Bonito.jl

![CI](https://github.com/SimonDanisch/Bonito.jl/workflows/CI/badge.svg) [![Codecov](https://codecov.io/gh/SimonDanisch/Bonito.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/SimonDanisch/Bonito.jl)
[![Docs - stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://simondanisch.github.io/Bonito.jl/stable/)

**Build interactive web applications, dashboards, and visualizations entirely in Julia.**

Bonito.jl enables you to create rich, reactive web applications using Julia's Observables for state management and a simple HTML/DOM API. It bridges Julia with the browser via WebSockets, allowing you to build anything from data exploration dashboards to interactive documentation—all without being locked into a specific frontend framework.

## Key Features

- **Reactive & Interactive**: Built on Observables.jl for automatic UI updates when data changes
- **Rich Component Library**: Buttons, sliders, tables, code editors, and custom widgets
- **Seamless Plotting**: Deeply integrated with WGLMakie, plus support for Plotly, Gadfly, and more
- **Deploy Anywhere**: Works in VSCode, Jupyter, Pluto, web servers, or export to static HTML
- **Javascript When You Need It**: Easy ES6 module integration and Javascript execution
- **Pure Julia Development**: Write your entire application in Julia, with optional Javascript for client side rendering

## Examples Built with Bonito

- **[BonitoBook.jl](https://bonitobook.org/)**: A Jupyter-like notebook environment
- **[makie.org](https://makie.org/)**: The Makie website is using Bonito's static site generator
- **WGLMakie**: Interactive WebGL-accelerated plotting library

## Quick Example

```julia
using Bonito

# Create a reactive counter app
app = App() do session
    count = Observable(0)
    button = Button("Click me!")
    on(button) do click
        count[] += 1
    end
    return DOM.div(button, DOM.h1("Count: ", count))
end

display(app) # display it in browser or plotpane
export_static("app.html", app) # generated self contained HTML file from App
export_static("folder", Routes("/" => app)) # Export static site (without Julia connection)
# Or serve it on a server
server = Server(app, "127.0.0.1", 8888)
# add it as different route
# regex, and even custom matchers are possible for routes, read more in the docs!
route!(app, "/my-route" => app)
```

Have a look at the [examples](https://github.com/SimonDanisch/Bonito.jl/tree/master/examples), or check out the most outstanding ones:

## Markdown support
https://github.com/SimonDanisch/Bonito.jl/blob/master/examples/markdown.jl
![markdown_vol](https://user-images.githubusercontent.com/1010467/88916397-48513480-d266-11ea-8741-c5246f7f2395.gif)


## Renchon et al., Argonne National Laboratory, unpublished
https://simondanisch.github.io/WGLDemos/soil/
![soil](https://user-images.githubusercontent.com/1010467/88913137-aa0ea000-d260-11ea-81b6-3e71ff18ff03.gif)


## [Oceananigans](https://github.com/CliMA/Oceananigans.jl)
https://simondanisch.github.io/WGLDemos/oceananigans/
![ocean](https://user-images.githubusercontent.com/1010467/88912988-6d42a900-d260-11ea-8d87-1f3eea552d1b.gif)

## Smarthome dashboard:

https://github.com/SimonDanisch/SmartHomy/blob/master/web_app.jl
![image](https://user-images.githubusercontent.com/1010467/88916549-8d756680-d266-11ea-8d38-cd57640e1495.png)


## Interactive Notebook:

https://nextjournal.com/Lobatto/FitzHugh-Nagumo
![simulation](https://user-images.githubusercontent.com/1010467/88912834-2f458500-d260-11ea-9a49-5e17f769ff53.gif)


## Sponsors

<img src="https://github.com/JuliaPlots/Makie.jl/blob/master/assets/BMBF_gefoerdert_2017_en.jpg?raw=true" width="300"/>
Förderkennzeichen: 01IS10S27, 2020
