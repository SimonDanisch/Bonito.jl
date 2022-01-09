using JSServe, WGLMakie, Makie, Colors, FileIO
using JSServe.DOM

function styled_slider(slider, value)
    rows(slider, DOM.span(value, class="p-1"), class="w-64 p-2 items-center")
end

columns(args...; class="") = DOM.div(args..., class=class * " flex flex-col")
rows(args...; class="") = DOM.div(args..., class=class * " flex flex-row")
css_color(c) = "background-color: #$(hex(c))"

# get a somewhat interesting point cloud:
cat = decompose(Point3f, load(Makie.assetpath("cat.obj")))
# Create a little interactive app
app = App() do session
    markersize = JSServe.Slider(range(1, stop=20, step=0.1))
    hue_slider = JSServe.Slider(1:360)
    color = map(hue_slider) do hue
        HSV(hue, 0.5, 0.5)
    end
    plot = scatter(cat, markersize=markersize, color=color, figure=(resolution=(500, 500),))
    m_slider = styled_slider(markersize, markersize.value)
    color_swatch = DOM.div(class="h-6 w-6 p-1 rounded dropshadow", style=map(css_color, color))
    h_slider = styled_slider(hue_slider, color_swatch)
    sliders = rows(m_slider, h_slider)
    dom =  DOM.div(JSServe.Styling, JSServe.TailwindCSS, columns(sliders, plot))
    return JSServe.record_states(session, dom)
end

mkdir("simple")
JSServe.export_standalone(app, "simple")
