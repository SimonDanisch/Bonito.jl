using Bonito, WGLMakie
using GeometryBasics
using FileIO
using Bonito: @js_str, onjs, App, Slider
using Bonito.DOM
Bonito.browser_display()

set_theme!(size=(1200, 800))

hbox(args...) = DOM.div(args...)
vbox(args...) = DOM.div(args...)

app = App() do
    return hbox(
        vbox(
            scatter(1:4, color=1:4),
            scatter(1:4, color=rand(RGBAf, 4)),
            scatter(1:4, color=rand(RGBf, 4)),
            scatter(1:4, color=:red),
            scatter(1:4)
        ),
        vbox(
            scatter(1:4, marker='☼'),
            scatter(1:4, marker=['☼', '◒', '◑', '◐']),
            scatter(1:4, marker=rand(RGBf, 10, 10), markersize=20),
            scatter(1:4, markersize=20),
            scatter(1:4, markersize=20, markerspace=:pixel),
            scatter(1:4, markersize=LinRange(20, 60, 4), markerspace=:pixel),
            scatter(1:4, marker='▲', markersize=0.3, markerspace=:data, rotation=LinRange(0, pi, 4)),
        )
    )
end

app = App() do
    return DOM.div(
        meshscatter(1:4, color=1:4),
        meshscatter(1:4, color=rand(RGBAf, 4)),
        meshscatter(1:4, color=rand(RGBf, 4)),
        meshscatter(1:4, color=:red),
        meshscatter(rand(Point3f, 10), color=rand(RGBf, 10)),
        meshscatter(rand(Point3f, 10), marker=Pyramid(Point3f(0), 1f0, 1f0)),
    )
end



app = App() do
    x = Point2f[(1, 1), (2, 2), (3, 2), (4, 4)]
    points = connect(x, LineFace{Int}[(1, 2), (2, 3), (3, 4)])
    return DOM.div(
        linesegments(1:4),
        linesegments(1:4, linestyle=:dot),
        linesegments(1:4, linestyle=[0.0, 1.0, 2.0, 3.0, 4.0]),
        linesegments(1:4, color=1:4),
        linesegments(1:4, color=rand(RGBf, 4), linewidth=10),
        linesegments(points)
    )
end


app = App() do
    x = Point2f[(1, 1), (2, 2), (3, 2), (4, 4)]
    points = connect(x, LineFace{Int}[(1, 2), (2, 3), (3, 4)])
    return DOM.div(
        lines(1:4),
        lines(1:4, linestyle=:dot),
        lines(1:4, linestyle=[0.0, 1.0, 2.0, 3.0, 4.0]),
        lines(1:4, color=1:4),
        lines(1:4, color=rand(RGBf, 4), linewidth=10),
        lines(points)
    )
end

app = App() do
    data = Makie.peaks()
    return hbox(vbox(
        surface(-10..10, -10..10, data, axis=(; show_axis=false)),
        surface(-10..10, -10..10, data, color=rand(size(data)...))),
        vbox(surface(-10..10, -10..10, data, color=rand(RGBf, size(data)...)),
        surface(-10..10, -10..10, data, colormap=:magma, colorrange=(0.0, 2.0)),
    ))
end

app = App() do
    return vbox(
        image(rand(10, 10)),
        heatmap(rand(10, 10)),
        image(rand(RGBAf, 10, 10)),
        heatmap(rand(RGBAf, 10, 10)),
        image(rand(RGBf, 10, 10)),
        heatmap(rand(RGBf, 10, 10)),
    )
end

using WGLMakie: volume

app = App() do
    return hbox(vbox(
        volume(rand(4, 4, 4), isovalue=0.5, isorange=0.01, algorithm=:iso),
        volume(rand(4, 4, 4), algorithm=:mip),
        volume(1..2, -1..1, -3..(-2), rand(4, 4, 4), algorithm=:absorption)),
        vbox(
        volume(rand(4, 4, 4), algorithm=Int32(5)),
        volume(rand(RGBAf, 4, 4, 4), algorithm=:absorptionrgba),
        contour(rand(4, 4, 4)),
    ))
end

app = App() do
    cat = FileIO.load(Makie.assetpath("cat.obj"))
    tex = FileIO.load(Makie.assetpath("diffusemap.png"))
    return hbox(vbox(
        Makie.mesh(Circle(Point2f(0), 1f0)),
        Makie.poly(decompose(Point2f, Circle(Point2f(0), 1f0)))), vbox(
        Makie.mesh(cat, color=tex),
        Makie.mesh([(0.0, 0.0), (0.5, 1.0), (1.0, 0.0)]; color=[:red, :green, :blue], shading=false)
    ))
end

function n_times(f, n=10, interval=1)
    obs = Observable(f(1))
    @async for i in 2:n
        try
            obs[] = f(i)
            sleep(interval)
        catch e
            @warn "Error!" exception=CapturedException(e, Base.catch_backtrace())
        end
    end
    return obs
end

app = App() do
    s1 = text(n_times(i-> map(j-> ("$j", Point2f(j*30, 0)), 1:i)), fontsize=20,
                      axis=(;limits=(30, 320, -5, 5)))
    s2 = scatter(n_times(i-> Point2f.((1:i).*30, 0)), markersize=20,
                  axis=(;limits=(30, 320, -5, 5)))
    s3 = linesegments(n_times(i-> Point2f.((2:2:2i).*30, 0)), axis=(;limits=(30, 620, -5, 5)))
    s4 = lines(n_times(i-> Point2f.((2:2:2i).*30, 0)), axis=(;limits=(30, 620, -5, 5)))
    return hbox(s1, s2, s3, s4)
end

app = App() do
    outer_padding = 30
    fig = Figure(
        figure_padding =outer_padding, resolution=(1200, 700),
        backgroundcolor = RGBf(0.98, 0.98, 0.98)
    )
    ax1 = Axis(fig[1,1], title="Sine")
    xx = 0:0.2:4pi
    line1 = lines!(ax1, sin.(xx), xx, color=:red)
    scat1 = scatter!(ax1, sin.(xx) .+ 0.2 .* randn.(), xx,
        color=(:red, 0.5), markersize=15, marker='■')
    return fig
end

app = App() do
    sl = Bonito.Slider(1:10)
    rect = Rect2f(0, -5, 1025, 10)
    chars = [collect('a':'z'); 0:9;]
    char2 = [collect('A':'Z'); 0:9;]
    tex1 = map(x->map(j-> ("$(chars[rand(1:length(chars))])", Point2f(j*30, 0)), 1:36), sl)
    on(println, tex1)
    tex2 = map(x->map(j-> ("$(char2[rand(1:length(char2))])", Point2f(j*30, 1)), 1:36), sl)
    fig, ax, pl = text(tex1, fontsize=20)
    text!(ax, tex2; fontsize=20)
    return DOM.div(sl, fig)
end
