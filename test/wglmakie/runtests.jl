using Bonito, WGLMakie, Test
using WGLMakie: Makie
import ElectronCall
const ECT = ElectronCall.Testing

function with_browser(f, app)
    server = Bonito.Server("127.0.0.1", 0)
    try
        Bonito.route!(server, "/" => app)
        ECT.open_window(; security = Bonito.HTTPServer.default_security_config(),
                        electron_args = [Bonito.HTTPServer.default_electron_args();
                                         "--use-angle=swiftshader"; "--enable-unsafe-swiftshader"]) do ctx
            ElectronCall.run(ctx.app, """(() => {
                const wc = electron.BrowserWindow.fromId($(ctx.window.id)).webContents;
                wc.testErrors = [];
                wc.on('console-message', event => {
                    if (event.level === 'error') wc.testErrors.push(event.message);
                });
                return true;
            })()""")
            ElectronCall.load(ctx.window, Bonito.HTTPServer.URI("http://127.0.0.1:$(server.port)"))
            @test ECT.wait_for(ctx, "typeof Bonito !== 'undefined'"; timeout = 60.0)
            try
                f(ctx)
            finally
                errors = ElectronCall.run(ctx.app,
                    "electron.BrowserWindow.fromId($(ctx.window.id)).webContents.testErrors")
                @test isempty(errors)
            end
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
                @test ECT.wait_for(ctx, "document.querySelector('canvas')?.width > 0"; timeout = 60.0)
                before = Makie.colorbuffer(fig)
                @test size(before) == (360, 480)
                @test length(unique(before)) > 10
                ECT.dom_click(ctx, "#move")
                @test ECT.wait_for(ctx, "document.querySelector('#clicked')?.textContent === '1'"; timeout = 10.0)
                moved = Makie.colorbuffer(fig)
                @test count(before .!= moved) > 100
                line = lines!(ax, Point2f[(0, 0), (2, 2)]; color = :blue, linewidth = 8)
                inserted = Makie.colorbuffer(fig)
                changed = count(inserted .!= moved)
                @test changed > 100
                delete!(ax, line)
                restored = Makie.colorbuffer(fig)
                @test count(restored .!= moved) < changed ÷ 10
                ECT.screenshot(ctx; path = joinpath(tempdir(), "bonito-wglmakie-$compressed.png"))
            end
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
            @assert ECT.wait_for(ctx, "document.querySelectorAll('canvas').length === 2"; timeout = 30.0)
            @test length(unique(Makie.colorbuffer(second))) > 10
            deferred[] = DOM.div()
            @test ECT.wait_for(ctx, "document.querySelectorAll('canvas').length === 1"; timeout = 30.0)
        end
    end

    @testset "standalone export" begin
        mktempdir() do dir
            first, _, _ = example_plot()
            second, _, _ = example_plot()
            path = joinpath(dir, "plots.html")
            Bonito.export_static(path, App(DOM.div(first, second)))
            with_browser(_ -> Bonito.HTTP.Response(200, ["Content-Type" => "text/html"], read(path))) do ctx
                @test ECT.wait_for(ctx, "document.querySelectorAll('canvas').length === 2 && " *
                    "[...document.querySelectorAll('canvas')].every(c => c.width > 0)"; timeout = 60.0)
                image = ECT.screenshot(ctx; path = joinpath(tempdir(), "bonito-wglmakie-offline.png"))
                @test length(unique(WGLMakie.PNGFiles.load(image))) > 10
            end
        end
    end
    Bonito.use_compression!(false)
end
