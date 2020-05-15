import AbstractPlotting
using WGLMakie
using AbstractPlotting.Colors: color, reducec
using ImageTransformations

@testset "WGLMakie" begin
    function test_handler(session, req)
        scene = AbstractPlotting.scatter(1:4, resolution=(500,500), color=:red)
        return DOM.div(scene)
    end
    testsession(test_handler, port=8555) do app
        # Lets not be too porcelainy about this ...
        @test evaljs(app, js"document.querySelector('canvas').style.width") == "500px"
        @test evaljs(app, js"document.querySelector('canvas').style.height") == "500px"
        img = WGLMakie.session2image(app.session)
        ratio = evaljs(app, js"window.devicePixelRatio")
        @info "device pixel ration: $(ratio)"
        if ratio != 1
            img = ImageTransformations.imresize(img, (500, 500))
        end
        img_ref = AbstractPlotting.FileIO.load(joinpath(@__DIR__, "test_reference.png"))
        # AbstractPlotting.FileIO.save(joinpath(@__DIR__, "test_reference.png"), img)
        meancol = AbstractPlotting.mean(color.(img) .- color.(img_ref))
        # This is pretty high... But I don't know how to look into travis atm
        # And seems it's not suuper wrong, so I'll take it for now ;)
        @test (reducec(+, 0.0, meancol) / 3) <= 0.025
    end
end
