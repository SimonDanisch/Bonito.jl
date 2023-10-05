# Plotting

```@example 1
using JSServe
using WGLMakie
import WGLMakie as W
import Gadfly as G
import PlotlyLight as PL
import JSServe.TailwindDashboard as D

Page()

function makie_plot()
    N = 10
    function xy_data(x, y)
        r = sqrt(x^2 + y^2)
        r == 0.0 ? 1.0f0 : (sin(r) / r)
    end
    l = range(-10, stop=10, length=N)
    z = Float32[xy_data(x, y) for x in l, y in l]
    W.surface(
        -1 .. 1, -1 .. 1, z,
        colormap=:Spectral,
        figure=(; resolution=(500, 500))
    )
end

# As far as I can tell, PlotlyLight doesn't handle require inside documenter correctly
# So we just use JSServe to do it correctly via `Asset`:
const Plotly = JSServe.Asset(PL.cdn_url[])
function JSServe.jsrender(session::Session, plot::PL.Plot)
    # Pretty much copied from the PlotlyLight source to create the JS + div for creating the plot:
    div = DOM.div(style="width: 400px;")
    src = js"""
        Plotly.newPlot($(div), $(plot.data), $(plot.layout), $(plot.config))
    """
    return JSServe.jsrender(session, DOM.div(Plotly, div, src))
end

App() do
    p = PL.Plot(x=1:20, y=cumsum(randn(20)), type="scatter", mode="lines+markers")
    width = "400px"
    G.set_default_plot_size(400G.px, 400G.px)
    gp = G.plot([sin, cos], 0, 2pi)
    return DOM.div(D.FlexGrid(
        D.Card(gp; width),
        D.Card(p; width),
        D.Card(makie_plot(); width); style="width: 900px"))
end
```
