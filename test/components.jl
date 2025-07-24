function styleable_slider_app(s, r)
    a = StylableSlider(1:4; value=1)
    b = StylableSlider(1:4; index=2)
    c = StylableSlider(["a", "b"]; value="b")
    return DOM.div(a, b, c)
end

@testset "StylableSlider" begin
    testsession(styleable_slider_app; port=8555) do app
        dom = app.dom
        a = children(dom)[1]
        @test a.value[] == 1
        @test a.index[] == 1
        b = children(dom)[2]
        @test b.value[] == 2
        @test b.index[] == 2
        c = children(dom)[3]
        @test c.value[] == "b"
        @test c.index[] == 2
    end
end

# @testset "Class with observable" begin
#     app = App() do
#         class = Observable("no-test")
#         jss = js"""
#             $(class).notify("test");
#         """
#         DOM.div(DOM.div("HEY HEY"; class=class), jss)
#     end
#     display(edisplay, app)
#     Bonito.wait_for_ready(app)
#     success = Bonito.wait_for() do
#         class = evaljs_value(app.session[], js"""(()=>{
#             const b = document.querySelector(".test");
#             if (!b) return "no class";
#             return b.className;
#         })()""")
#         return class == "test"
#     end
#     @test success == :success
# end
