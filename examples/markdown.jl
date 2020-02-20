using Hyperscript, Markdown
using JSServe, Observables
using JSServe: Session, evaljs, linkjs, div, active_sessions
using JSServe: @js_str, onjs, Button, TextField, Slider, JSString, Dependency, Asset
using WGLMakie, AbstractPlotting

markdown_css = Asset(JSServe.dependency_path("markdown.css"))

function test_handler(session, req)
    button = Button("click")
    slider = Slider(1:100)

    signal = map(slider) do value
        sin.(LinRange(0, value, 1000))
    end

    scene = scatter(signal, markersize=(10.0,10.0), resolution=(500,200), limits=FRect(0, -1, 1000, 2))

    on(button) do val
        scene[end].color = rand(RGBf0)
    end
    dom = md"""
    # More MD

    [Github-flavored Markdown info page](http://github.github.com/github-flavored-markdown/)

    [![Build Status](https://travis-ci.com/SimonDanisch/JSServe.jl.svg?branch=master)](https://travis-ci.com/SimonDanisch/JSServe.jl)

    Lalala
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

    $(slider)

    $(button)

    ---

    $(scene)

    ---
    """
    return JSServe.DOM.div(markdown_css, dom)
end

app = JSServe.Application(test_handler, "0.0.0.0", 8081)
