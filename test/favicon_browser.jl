@testset "Browser favicon" begin
    icon = Asset(joinpath(@__DIR__, "..", "docs", "src", "assets", "favicon.ico"))
    server = Server("127.0.0.1", 0)
    route!(server, "/plain" => App(DOM.div("Ready"); favicon = icon))
    route!(server, "/custom" => App(DOM.html(DOM.head(DOM.title("Custom")), DOM.body("Ready")); favicon = icon))
    route!(server, "/loading" => App(() -> DOM.div("Ready"); favicon = icon, loading_page = Bonito.LoadingPage()))
    route!(server, "/svg" => App(DOM.div("SVG"); favicon = Asset(joinpath(@__DIR__, "..", "docs", "src", "assets", "bonito-dark.svg"))))
    route!(server, "/png" => App(DOM.div("PNG"); favicon = joinpath(@__DIR__, "..", "docs", "src", "jupyterlab.png")))
    window = TestWindow()
    display_backend = Bonito.HTTPServer.ElectronDisplay(window, Bonito.HTTPServer.BrowserDisplay(server, false, nothing))
    try
        for path in ("/plain", "/custom", "/loading", "/svg", "/png")
            ElectronCall.load(window.window, URI(Bonito.online_url(server, path)))
            @test run(window, "document.head.querySelectorAll('link[rel=icon]').length") == 1
            @test run(
                window, """(async () => {
                    const icon = document.head.querySelector('link[rel=icon]');
                    const response = await fetch(icon.href);
                    const image = new Image();
                    image.src = icon.href;
                    await image.decode();
                    return response.ok && image.naturalWidth > 0;
                })()"""
            )
        end

        display(display_backend, App(DOM.div("Display"); favicon = icon))
        @test run(window, "document.head.querySelectorAll('link[rel=icon]').length") == 1
        @test run(window, "document.body.textContent.includes('Display')")
    finally
        close(display_backend)
        close(server)
    end
end
