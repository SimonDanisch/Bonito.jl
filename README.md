# Bonito.jl

![CI](https://github.com/SimonDanisch/Bonito.jl/workflows/CI/badge.svg) [![Codecov](https://codecov.io/gh/SimonDanisch/Bonito.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/SimonDanisch/Bonito.jl)
[![Docs - stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://simondanisch.github.io/Bonito.jl/stable/)

**Build interactive web applications, dashboards, and visualizations entirely in Julia.**

Bonito.jl enables you to create rich, reactive web applications using Julia's [Observables](https://juliagizmos.github.io/Observables.jl/stable/) for state management and a simple HTML/DOM API. 
Observables can communicate with the Frontend via a performance optimized WebSocket connection, allowing you to build anything from data exploration dashboards to interactive documentation—all without being locked into a specific frontend framework.

## Key Features

- **Reactive & Interactive**: Built on Observables.jl for automatic UI updates when data changes, only sending the minimal amount of data possible via a fast binary serialization protocol
- **Rich Component Library**: Buttons, sliders, tables, code editors, and easy to build custom widgets
- **Seamless Plotting**: Deeply integrated with WGLMakie, plus support for Plotly, Gadfly, and more
- **Deploy Anywhere**: Works in VSCode, Jupyter, Pluto, web servers, or export to static HTML
- **Javascript When You Need It**: Easy ES6 module integration and Javascript execution
- **Pure Julia Development**: Write your entire application in Julia, with optional Javascript for client side rendering
- **Extensible Handlers**: Wrap and compose handlers for authentication, logging, static files, and custom middleware

## Quick Example

```julia
using Bonito
# Create a reactive counter app
app = App() do session
    count = Observable(0)
    button = Button("Click me!")
    on(click-> (count[] += 1), button)
    return DOM.div(button, DOM.h1("Count: ", count))
end
display(app) # display it in browser or plotpane
export_static("app.html", app) # generated self contained HTML file from App
export_static("folder", Routes("/" => app)) # Export static site (without Julia connection)
# Or serve it on a server
server = Server(app, "127.0.0.1", 8888)
# add it as different route
# regex, and even custom matchers are possible for routes, read more in the docs!
route!(server, "/my-route" => app)
```

## Examples Built with Bonito

### [makie.org](https://makie.org/)

The Makie website is using Bonito's static site generator

### [WGLMakie](https://docs.makie.org/dev/explanations/backends/wglmakie#WGLMakie)

Interactive WebGL-accelerated plotting library

https://github.com/user-attachments/assets/0d13b88b-5a34-4785-91a2-c1d8a1304074

[taken from ClimaAtmos.jl](https://github.com/CliMA/ClimaAtmos.jl)

### [BonitoBook](https://bonitobook.org/)

A customizable, Jupyter-like notebook environment

https://github.com/user-attachments/assets/ad8bd118-1a82-4799-b1ba-6220072557c7

https://github.com/user-attachments/assets/55e110c8-c144-41ab-8537-65cbc17a63e0

## [NetworkDynamicsInspector](https://github.com/JuliaDynamics/NetworkDynamics.jl/tree/main/NetworkDynamicsInspector)

NetworkDynamicsInspector.jl is an extension package to NetworkDynamics.jl which provides a WebApp based on Bonito.jl and WGLMakie.jl for interactive visualization of solutions to systems based on network dynamics.

https://github.com/user-attachments/assets/064a6138-610f-48d7-8e2e-d174fa710ddb

### [Example folder](https://github.com/SimonDanisch/Bonito.jl/tree/master/examples)

Have a look at some of the usage examples for Bonito, like the [interactive markdown rendering support](https://github.com/SimonDanisch/Bonito.jl/blob/master/examples/markdown.jl):

https://github.com/user-attachments/assets/e8120b9c-ddfb-4f6f-bea8-97ee56ee646d


## Sponsors

<img src="https://github.com/user-attachments/assets/7fa49123-eb57-47eb-b8f9-caa887df725c" width="300"/>
Förderkennzeichen: 01IS10S27, 2020
