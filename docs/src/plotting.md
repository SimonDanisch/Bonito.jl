# Plotting

All plotting frameworks overloading the Julia display system should work out of the box and all Javascript plotting libraries should be easy to integrate!
The following example shows how to integrate popular libraries like Makie, Plotly and Gadfly.

```@example 1
using Bonito
using WGLMakie
import WGLMakie as W
import Gadfly as G
import PlotlyLight as PL

Page() # required for multi cell output inside documenter

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
        figure=(; size=(300, 300))
    )
end

# As far as I can tell, PlotlyLight doesn't handle require inside documenter correctly
# So we just use Bonito to do it correctly via `Asset`:
const Plotly = Bonito.Asset(PL.plotly.url)

function Bonito.jsrender(session::Session, plot::PL.Plot)
    # Pretty much copied from the PlotlyLight source to create the JS + div for creating the plot:
    div = DOM.div(style="width: 300px;height: 300px;")
    src = js"""
        Plotly.newPlot($(div), $(plot.data), $(plot.layout), $(plot.config))
    """
    return Bonito.jsrender(session, DOM.div(Plotly, div, src))
end

App() do
    p = PL.plot(x = 1:20, y = cumsum(randn(20)), type="scatter", mode="lines+markers")
    G.set_default_plot_size(300G.px, 300G.px)
    gp = G.plot([sin, cos], 0, 2pi)
    # The plots already leave lots of white space
    PCard(p) = Card(p, padding="0px", margin="0px")
    return Grid(
        PCard(gp),
        PCard(p),
        PCard(makie_plot());
        columns="repeat(auto-fit, minmax(300px, 1fr))", justify_items="center")
end
```
