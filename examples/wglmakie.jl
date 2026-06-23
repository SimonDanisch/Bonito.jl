using JSServe
using WGLMakie
using GeometryBasics
using FileIO
using WGLMakie: px
using JSServe: @js_str, onjs, App, Slider
using JSServe.DOM

JSServe.browser_display()

set_theme!(resolution=(1200, 800))

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
            scatter(1:4, marker="☼◒◑◐"),
            # scatter(1:4, marker=rand(RGBf, 10, 10), markersize=20px),
            scatter(1:4, markersize=20px),
            scatter(1:4, markersize=20, markerspace=Pixel),
            scatter(1:4, markersize=LinRange(20, 60, 4), markerspace=Pixel),
            scatter(1:4, marker='▲', markersize=0.3, rotations=LinRange(0, pi, 4)),
        )
    )
end

display(app)

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

display(app)


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

display(app)

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

display(app)

app = App() do
    data = AbstractPlotting.peaks()
    return hbox(vbox(
        surface(-10..10, -10..10, data, show_axis=false),
        surface(-10..10, -10..10, data, color=rand(size(data)...))),
        vbox(surface(-10..10, -10..10, data, color=rand(RGBf, size(data)...)),
        surface(-10..10, -10..10, data, colormap=:magma, colorrange=(0.0, 2.0)),
    ))
end

display(app)

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

display(app)

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

display(app)


app = App() do
    cat = FileIO.load(MakieGallery.assetpath("cat.obj"))
    tex = FileIO.load(MakieGallery.assetpath("diffusemap.png"))
    return hbox(vbox(
        AbstractPlotting.mesh(Circle(Point2f(0), 1f0)),
        AbstractPlotting.poly(decompose(Point2f, Circle(Point2f(0), 1f0)))), vbox(
        AbstractPlotting.mesh(cat, color=tex),
        AbstractPlotting.mesh([(0.0, 0.0), (0.5, 1.0), (1.0, 0.0)]; color=[:red, :green, :blue], shading=false)
    ))
end

display(app)

function n_times(f, n=10, interval=0.5)
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
    s1 = annotations(n_times(i-> map(j-> ("$j", Point2f(j*30, 0)), 1:i)), textsize=20,
                      limits=Rect2f(30, 0, 320, 50))
    s2 = scatter(n_times(i-> Point2f.((1:i).*30, 0)), markersize=20px,
                  limits=Rect2f(30, 0, 320, 50))
    s3 = linesegments(n_times(i-> Point2f.((2:2:2i).*30, 0)), limits=Rect2f(30, 0, 620, 50))
    s4 = lines(n_times(i-> Point2f.((2:2:2i).*30, 0)), limits=Rect2f(30, 0, 620, 50))
    return hbox(s1, s2, s3, s4)
end

display(app)


app = App() do
    outer_padding = 30
    scene, layout = layoutscene(
        outer_padding, resolution=(1200, 700),
        backgroundcolor=RGBf(0.98, 0.98, 0.98)
    )
    ax1 = layout[1, 1] = LAxis(scene, title="Sine")
    xx = 0:0.2:4pi
    line1 = lines!(ax1, sin.(xx), xx, color=:red)
    scat1 = scatter!(ax1, sin.(xx) .+ 0.2 .* randn.(), xx,
        color=(:red, 0.5), markersize=15px, marker='■')
    return scene
end

display(app)


app = App() do
    scene = Scene(resolution=(1000, 1000));
    campixel!(scene);

    maingl = GridLayout(scene, alignmode=Outside(30))

    las = Array{LAxis,2}(undef, 4, 4)

    for i in 1:4, j in 1:4
        las[i, j] = maingl[i, j] = LAxis(scene)
    end

    las[4, 1].attributes.aspect = AxisAspect(1)
    las[4, 2].attributes.aspect = AxisAspect(2)
    las[4, 3].attributes.aspect = AxisAspect(0.5)
    las[4, 4].attributes.aspect = nothing
    las[1, 1].attributes.maxsize = (Inf, Inf)
    las[1, 2].attributes.aspect = nothing
    las[1, 3].attributes.aspect = nothing

    subgl = gridnest!(maingl, 1, 1)
    cb1 = subgl[:, 2] = LColorbar(scene, width=30, height=Relative(0.66))

    subgl2 = gridnest!(maingl, 1:2, 1:2)
    cb2 = subgl2[:, 3] = LColorbar(scene, width=30, height=Relative(0.66))

    subgl3 = gridnest!(maingl, 1:3, 1:3)
    cb3 = subgl3[:, 4] = LColorbar(scene, width=30, height=Relative(0.66))

    subgl4 = gridnest!(maingl, 1:4, 1:4)
    cb4 = subgl4[:, 5] = LColorbar(scene, width=30, height=Relative(0.66))
    return scene

end

display(app)


app = App() do
    sl = JSServe.Slider(1:10)
    rect = Rect2f(0, -5, 1025, 10)
    chars = [collect('a':'z'); 0:9;]
    char2 = [collect('A':'Z'); 0:9;]
    tex1 = map(x->map(j-> ("$(chars[rand(1:length(chars))])", Point2f(j*30, 0)), 1:36), sl)
    tex2 = map(x->map(j-> ("$(char2[rand(1:length(char2))])", Point2f(j*30, 1)), 1:36), sl)
    scene = annotations(tex1, textsize=20, limits=rect, show_axis=false)
    annotations!(scene, tex2, textsize=20, limits=rect, show_axis=false)
    return DOM.div(sl, scene)
end

display(app)
