using Markdown
using JSServe, Observables
using JSServe: Session, evaljs, linkjs
using JSServe: @js_str, onjs, Button, Slider, Asset
using WGLMakie, AbstractPlotting
using JSServe.DOM

app = App() do
    cmap_button = Button("change colormap")
    algorithm_button = Button("change algorithm")
    algorithms = ["mip", "iso", "absorption"]
    algorithm = Observable(first(algorithms))
    dropdown_onchange = js"JSServe.update_obs($algorithm, this.options[this.selectedIndex].text);"
    algorithm_drop = DOM.select(DOM.option.(algorithms); class="bandpass-dropdown", onclick=dropdown_onchange)

    data_slider = Slider(LinRange(1f0, 10f0, 100))
    iso_value = Slider(LinRange(0f0, 1f0, 100))
    N = 100
    slice_idx = Slider(1:N)

    signal = map(Observables.async_latest(data_slider.value)) do α
        a = -1; b = 2
        r = LinRange(-2, 2, N)
        z = ((x,y) -> x + y).(r, r') ./ 5
        me = [z .* sin.(α .* (atan.(y ./ x) .+ z.^2 .+ pi .* (x .> 0))) for x=r, y=r, z=r]
        return me .* (me .> z .* 0.25)
    end

    slice = map(signal, slice_idx) do x, idx
        view(x, :, idx, :)
    end
    fig = Figure()

    vol = volume(fig[1,1], signal; algorithm=map(Symbol, algorithm), ambient=Vec3f(0.8), isovalue=iso_value)

    colormaps = collect(AbstractPlotting.all_gradient_names)
    cmap = map(cmap_button) do click
        return colormaps[rand(1:length(colormaps))]
    end

    heat = heatmap(fig[1, 2], slice, colormap=cmap)

    dom = md"""
    # More MD

    [Github-flavored Markdown info page](http://github.github.com/github-flavored-markdown/)

    [![Build Status](https://travis-ci.com/SimonDanisch/JSServe.jl.svg?branch=master)](https://travis-ci.com/SimonDanisch/JSServe.jl)

    Thoughtful example
    ======

    Alt-H2
    ------

    *italic* or **bold**

    Combined emphasis with **asterisks and _underscores_**.

    1. First ordered list item
    2. Another item
        * Unordered sub-list.
    1. Actual numbers don't matter, just that it's a number
        1. Ordered sub-list

    * Unordered list can use asterisks

    Inline `code` has `back-ticks around` it.
    ```julia
    test("haha")
    ```

    ---
    # JSServe

    [![Build Status](https://travis-ci.com/SimonDanisch/JSServe.jl.svg?branch=master)](https://travis-ci.com/SimonDanisch/JSServe.jl)
    [![Build Status](https://ci.appveyor.com/api/projects/status/github/SimonDanisch/JSServe.jl?svg=true)](https://ci.appveyor.com/project/SimonDanisch/JSServe-jl)
    [![Codecov](https://codecov.io/gh/SimonDanisch/JSServe.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/SimonDanisch/JSServe.jl)
    [![Build Status](https://travis-ci.com/SimonDanisch/JSServe.jl.svg?branch=master)](https://travis-ci.com/SimonDanisch/JSServe.jl)


    | Tables        | Are           | Cool  |
    | ------------- |:-------------:| -----:|
    | col 3 is      | right-aligned | $1600 |
    | col 2 is      | centered      |   $12 |
    | zebra stripes | are neat      |    $1 |

    > Blockquotes are very handy in email to emulate reply text.
    > This line is part of the same quote.

    # Plots:

    $(DOM.div("data param", data_slider))

    $(DOM.div("iso value", iso_value))

    $(DOM.div("y slice", slice_idx))

    $(algorithm_drop)

    $(cmap_button)

    ---

    $(fig.scene)

    ---
    """
    return JSServe.DOM.div(JSServe.MarkdownCSS, JSServe.Styling, dom)
end

display(app)
