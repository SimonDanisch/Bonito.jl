using Bonito, Observables, Markdown, Colors
using Bonito: Asset
style_obs = Observable((color = :red,))

slider = Bonito.Slider(1:10, class="slider m-4")


example_dom = DOM.div(
    DOM.h1("hi", style=style_obs),
    slider,
    DOM.div(js"""
        console.log("hello")
    """),
    DOM.img(src=Asset("/test.png")),
    rand(RGBA{Float32}, 10, 10),
    md"""
    # Hi this is a test
    ![]($(Asset(/test.png))
    """
)

session = Session()

Bonito.jsrender(session, example_dom)

obs_dom = Observable(example_dom)
obs_arrays = Observable(
    [
        rand(UInt8, 10),
        rand(Int32, 10),
        rand(UInt32, 10),
        rand(Float16, 10),
        rand(Float32, 10),
        rand(Float64, 10),
    ]
)

test_js = js"""
import * as TestMod from $(TestMod)

const dom_ref = $(existing_dom)
const new_dom = $(by_value(new_dom))
const obs_dom = $(obs_dom)
const obs_arrays = $(obs_arrays)
const obs_dict = $(obs)
"""
