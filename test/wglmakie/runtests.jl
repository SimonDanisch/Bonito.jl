using Bonito, WGLMakie, Test
using WGLMakie: Makie
import ElectronCall

browser_js(ctx, code) = ElectronCall.run(ctx.window, code)
wait_js(ctx, code; timeout = 10.0) =
    Bonito.wait_for(() -> browser_js(ctx, code) === true; timeout) === :success

function screenshot(ctx; path)
    image = ElectronCall.run(ctx.app, """
        (async () => {
            const win = electron.BrowserWindow.fromId($(ctx.window.id));
            return (await win.webContents.capturePage()).toPNG().toString('base64');
        })()
    """)
    write(path, Bonito.Base64.base64decode(image))
    return path
end

function with_browser(f, app)
    server = Bonito.Server("127.0.0.1", 0)
    try
        Bonito.route!(server, "/" => app)
        window = Bonito.EWindow(; options = Dict{String, Any}("show" => false,
            "webPreferences" => Dict("backgroundThrottling" => false)),
            electron_args = [Bonito.HTTPServer.default_electron_args();
                             "--use-angle=swiftshader"; "--enable-unsafe-swiftshader"])
        ctx = (app = window.app, window = window.window)
        try
            ElectronCall.run(ctx.app, """(() => {
                const wc = electron.BrowserWindow.fromId($(ctx.window.id)).webContents;
                wc.testErrors = [];
                wc.on('console-message', event => {
                    if (event.level === 'error') wc.testErrors.push(event.message);
                });
                return true;
            })()""")
            ElectronCall.load(ctx.window, Bonito.HTTPServer.URI("http://127.0.0.1:$(server.port)"))
            @test wait_js(ctx, "typeof Bonito !== 'undefined'"; timeout = 60.0)
            try
                f(ctx)
            finally
                errors = ElectronCall.run(ctx.app,
                    "electron.BrowserWindow.fromId($(ctx.window.id)).webContents.testErrors")
                @test isempty(errors)
            end
        finally
            close(window)
            close(window.app)
        end
    finally
        close(server)
    end
end

function example_plot()
    positions = Observable(Point2f[(0, 0), (1, 1), (2, 0)])
    fig = Figure(size = (480, 360))
    ax = Axis(fig[1, 1]; title = "WGLMakie glyphs: abc 123")
    scatter!(ax, positions; markersize = 25, color = :red)
    limits!(ax, -1, 3, -1, 3)
    return fig, ax, positions
end

@testset "WGLMakie downstream" begin
    Bonito.force_connection!(Bonito.WebSocketConnection)
    Bonito.force_asset_server!()
    WGLMakie.activate!(px_per_unit = 1.0)
    for compressed in (false, true)
        @testset "live plots (compression=$compressed)" begin
            Bonito.use_compression!(compressed)
            fig, ax, positions = example_plot()
            clicked = Observable(0)
            app = App() do session
                on(session, clicked) do value
                    positions[] = Point2f[(0, 2), (1, 0), (2, 2)]
                end
                DOM.div(
                    DOM.button("Move points"; id = "move", onclick = js"() => $(clicked).notify(1)"),
                    DOM.span(clicked; id = "clicked"), fig)
            end
            with_browser(app) do ctx
                @test wait_js(ctx, "document.querySelector('canvas')?.width > 0"; timeout = 60.0)
                before = Makie.colorbuffer(fig)
                @test size(before) == (360, 480)
                @test length(unique(before)) > 10
                browser_js(ctx, "document.querySelector('#move').click()")
                @test wait_js(ctx, "document.querySelector('#clicked')?.textContent === '1'"; timeout = 10.0)
                moved = Makie.colorbuffer(fig)
                @test count(before .!= moved) > 100
                line = lines!(ax, Point2f[(0, 0), (2, 2)]; color = :blue, linewidth = 8)
                inserted = Makie.colorbuffer(fig)
                changed = count(inserted .!= moved)
                @test changed > 100
                delete!(ax, line)
                restored = Makie.colorbuffer(fig)
                @test count(restored .!= moved) < changed ÷ 10
                screenshot(ctx; path = joinpath(tempdir(), "bonito-wglmakie-$compressed.png"))
            end
        end
    end

    @testset "3D geometry, volume and image textures" begin
        fig = Figure(size = (800, 360))
        xs = range(-1f0, 1f0; length = 12)
        surface!(Axis3(fig[1, 1]), xs, xs, [x^2 - y^2 for x in xs, y in xs])
        volume!(Axis3(fig[1, 2]), reshape(collect(range(0f0, 1f0; length = 216)), 6, 6, 6);
                algorithm = :mip)
        pixels = Observable(fill(RGBAf(1, 0, 0, 1), 16, 16))
        image!(Axis(fig[1, 3]), pixels)
        with_browser(App(fig)) do ctx
            @assert wait_js(ctx, "document.querySelector('canvas')?.width > 0"; timeout = 60.0)
            before = Makie.colorbuffer(fig)
            @test length(unique(before)) > 100
            pixels[] = fill(RGBAf(0, 0, 1, 1), 16, 16)
            @test count(before .!= Makie.colorbuffer(fig)) > 100
            screenshot(ctx; path = joinpath(tempdir(), "bonito-wglmakie-3d.png"))
        end
    end

    @testset "proxied plot and deferred content" begin
        fig, _, positions = example_plot()
        deferred = Observable{Any}(DOM.div())
        app = App() do host
            DOM.div(Bonito.embed_app(host, App(fig)), deferred)
        end
        with_browser(app) do ctx
            before = Makie.colorbuffer(fig)
            positions[] = Point2f[(0, 2), (1, 0), (2, 2)]
            @test count(before .!= Makie.colorbuffer(fig)) > 100
            second, _, _ = example_plot()
            deferred[] = second
            @assert wait_js(ctx, "document.querySelectorAll('canvas').length === 2"; timeout = 30.0)
            @test length(unique(Makie.colorbuffer(second))) > 10
            deferred[] = DOM.div()
            @test wait_js(ctx, "document.querySelectorAll('canvas').length === 1"; timeout = 30.0)
        end
    end

    @testset "standalone export" begin
        mktempdir() do dir
            first, _, _ = example_plot()
            second, _, _ = example_plot()
            path = joinpath(dir, "plots.html")
            Bonito.export_static(path, App(DOM.div(first, second)))
            with_browser(_ -> Bonito.HTTP.Response(200, ["Content-Type" => "text/html"], read(path))) do ctx
                @test wait_js(ctx, "document.querySelectorAll('canvas').length === 2 && " *
                    "[...document.querySelectorAll('canvas')].every(c => c.width > 0)"; timeout = 60.0)
                image = screenshot(ctx; path = joinpath(tempdir(), "bonito-wglmakie-offline.png"))
                @test length(unique(WGLMakie.PNGFiles.load(image))) > 10
            end
        end
    end
    Bonito.use_compression!(false)
end
