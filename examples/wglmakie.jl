using JSServe, Observables, WGLMakie, AbstractPlotting
using JSServe: @js_str, onjs, with_session, onload, Button, TextField, Slider, linkjs, serve_dom
using JSServe.DOM
using GeometryBasics
using MakieGallery, FileIO
set_theme!(resolution=(1200, 800))


function dom_handler(session, request)
    return hbox(
        vbox(
            scatter(1:4, color=1:4),
            scatter(1:4, color=rand(RGBAf0, 4)),
            scatter(1:4, color=rand(RGBf0, 4)),
            scatter(1:4, color=:red),
            scatter(1:4)
        ),
        vbox(
            scatter(1:4, marker='☼'),
            scatter(1:4, marker=['☼', '◒', '◑', '◐']),
            scatter(1:4, marker="☼◒◑◐"),
            # scatter(1:4, marker=rand(RGBf0, 10, 10), markersize=20px),
            scatter(1:4, markersize=20px),
            scatter(1:4, markersize=20, markerspace=Pixel),
            scatter(1:4, markersize=LinRange(20, 60, 4), markerspace=Pixel),
            scatter(1:4, marker='▲', markersize=0.3, rotations=LinRange(0, pi, 4)),
            )
        )
end

function dom_handler(session, request)
    return DOM.div(
        meshscatter(1:4, color=1:4),
        meshscatter(1:4, color=rand(RGBAf0, 4)),
        meshscatter(1:4, color=rand(RGBf0, 4)),
        meshscatter(1:4, color=:red),
        meshscatter(rand(Point3f0, 10), color=rand(RGBf0, 10)),
        meshscatter(rand(Point3f0, 10), marker=Pyramid(Point3f0(0), 1f0, 1f0)),
    )
end

function dom_handler(session, request)
    x = Point2f0[(1, 1), (2, 2), (3, 2), (4, 4)]
    points = connect(x, LineFace{Int}[(1, 2), (2, 3), (3, 4)])
    return DOM.div(
        linesegments(1:4),
        linesegments(1:4, linestyle=:dot),
        linesegments(1:4, linestyle=[0.0, 1.0, 2.0, 3.0, 4.0]),
        linesegments(1:4, color=1:4),
        linesegments(1:4, color=rand(RGBf0, 4), linewidth=4),
        linesegments(points)
    )
end

function dom_handler(session, request)
    data = AbstractPlotting.peaks()
    return hbox(vbox(
        surface(-10..10, -10..10, data, show_axis=false),
        surface(-10..10, -10..10, data, color=rand(size(data)...))),
        vbox(surface(-10..10, -10..10, data, color=rand(RGBf0, size(data)...)),
        surface(-10..10, -10..10, data, colormap=:magma, colorrange=(0.0, 2.0)),
    ))
end

function dom_handler(session, request)
    return vbox(
        image(rand(10, 10)),
        heatmap(rand(10, 10)),
    )
end

function dom_handler(session, request)
    return hbox(vbox(
        volume(rand(4, 4, 4), isovalue=0.5, isorange=0.01, algorithm=:iso),
        volume(rand(4, 4, 4), algorithm=:mip),
        volume(1..2, -1..1, -3..(-2), rand(4, 4, 4), algorithm=:absorption)),
        vbox(
        volume(rand(4, 4, 4), algorithm=Int32(5)),
        volume(rand(RGBAf0, 4, 4, 4), algorithm=:absorptionrgba),
        contour(rand(4, 4, 4)),
    ))
end

function dom_handler(session, request)
    cat = FileIO.load(MakieGallery.assetpath("cat.obj"))
    tex = FileIO.load(MakieGallery.assetpath("diffusemap.png"))
    return hbox(vbox(
        AbstractPlotting.mesh(Circle(Point2f0(0), 1f0)),
        AbstractPlotting.poly(decompose(Point2f0, Circle(Point2f0(0), 1f0)))), vbox(
        AbstractPlotting.mesh(cat, color=tex),
        AbstractPlotting.mesh([(0.0, 0.0), (0.5, 1.0), (1.0, 0.0)]; color=[:red, :green, :blue], shading=false)
    ))
end

function dom_handler(session, request)
    scene = scatter(rand(4) .* 4, color=1:4, limits=FRect2D(0, 0, 4, 4))
    scatter_plot = scene[end]
    @async begin
        for i in 1:100
            scatter_plot[1] = rand(4) .* 4
            sleep(0.01)
        end
    end
    return scene
end

isdefined(Main, :app) && close(app)
app = JSServe.Application(dom_handler, "127.0.0.1", 8081)
