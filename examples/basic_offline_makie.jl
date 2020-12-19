using JSServe, WGLMakie, AbstractPlotting, Colors
using JSServe.DOM

function styled_slider(slider, value)
    rows(slider, DOM.span(value, class="p-1"), class="w-64 p-2 items-center")
end
columns(args...; class="") = DOM.div(args..., class=class * " flex flex-col")
rows(args...; class="") = DOM.div(args..., class=class * " flex flex-row")
css_color(c) = "background-color: #$(hex(c))"
using MakieGallery, FileIO
# get a somewhat interesting point cloud:
cat = decompose(Point3f0, MakieGallery.loadasset("cat.obj"))
# Create a little interactive app
function App(session, request)
    markersize = JSServe.Slider(range(1, stop=20, step=0.1))
    hue_slider = JSServe.Slider(1:360)
    color = map(hue_slider) do hue
        HSV(hue, 0.5, 0.5)
    end
    plot = scatter(cat, markersize=markersize, color=color, resolution=(500, 500), show_axis=false)
    m_slider = styled_slider(markersize, markersize.value)
    color_swatch = DOM.div(class="h-6 w-6 p-1 rounded dropshadow", style=map(css_color, color))
    h_slider = styled_slider(hue_slider, color_swatch)
    sliders = rows(m_slider, h_slider)
    return DOM.div(JSServe.Styling, JSServe.TailwindCSS, columns(sliders, plot))
end
AppInteraktive(s, r) = JSServe.record_state_map(s, App(s, r)).dom

s = JSServe.Session()
states = AppInteraktive(s, nothing)
sizeof(MsgPack.pack(x)) / 10^6
mkdir("simple")
JSServe.export_standalone(AppInteraktive, "simple")


server = JSServe.Server(app, "0.0.0.0", 8081)
close(server)
