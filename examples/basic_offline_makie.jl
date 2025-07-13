using Bonito, WGLMakie, Makie, Colors, FileIO
using Bonito.DOM

function styled_slider(slider, value)
    rows(slider, DOM.span(value, class="p-1"), class="w-64 p-2 items-center")
end

columns(args...; class="") = DOM.div(args..., class=class * " flex flex-col")
rows(args...; class="") = DOM.div(args..., class=class * " flex flex-row")
css_color(c) = "background-color: #$(hex(c))"

# get a somewhat interesting point cloud:
cat = decompose(Point3f, FileIO.load(Makie.assetpath("cat.obj")))
# Create a little interactive app
app = App() do session
    markersize = Bonito.Slider(range(10, stop=100, length=100))
    hue_slider = Bonito.Slider(1:120)
    color = map(hue_slider) do hue
        HSV(hue, 0.5, 0.5)
    end
    f, ax, pl = scatter(cat, markersize=markersize.value, color=color, figure=(size=(800, 500),))
    m_slider = styled_slider(markersize, map(x -> round(x, digits=1), markersize.value))
    color_swatch = DOM.div(class="h-6 w-6 p-1 rounded dropshadow", style=map(css_color, color))
    h_slider = styled_slider(hue_slider, color_swatch)
    sliders = rows(m_slider, h_slider)
    dom = DOM.div(Bonito.Styling, Bonito.TailwindCSS, columns(sliders, f))
    return Bonito.record_states(session, dom)
end;


# mkdir("simple")
Bonito.export_static("simple.html", app)
