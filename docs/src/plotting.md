# Plotting

```@example 1
using JSServe
using WGLMakie
import WGLMakie as W
import Plots as P
import PlotlyLight as PL
import JSServe.TailwindDashboard as D
Page()
function makie_plot()
    N = 60
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

PL.Defaults.parent_style[] = "height: 300px; width: 400px"
App() do
    p = PL.Plot(x=1:20, y=cumsum(randn(20)), type="scatter", mode="lines+markers")
    width = "400px"
    return D.FlexRow(
        JSServe.Asset(PL.plotlyjs),
        D.Card(P.scatter(1:4; windowsize=(200, 200)); width),
        D.Card(p; width),
        D.Card(makie_plot()); width)
end
```
