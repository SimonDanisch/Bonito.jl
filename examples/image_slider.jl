using JSServe, FileIO, Colors, Observables
using JSServe.DOM

dir = mktempdir()
for i in 1:5
    save(joinpath(dir, "img$i.jpg"), rand(RGB{Colors.N0f8}, 200, 200))
end

function dom_handler(session, request)
    files = JSServe.Asset.(joinpath.(dir, filter(x-> endswith(x, ".jpg"), readdir(dir))))
    slider = JSServe.Slider(1:length(files))
    image_obs = Observable(first(files))
    img = DOM.img(src=image_obs, style="height: 200px;")
    on(slider) do idx
        image_obs[] = files[idx]
    end
    return DOM.div(slider, img)
end

isdefined(Main, :app) && close(app)
app = JSServe.Application(dom_handler, "127.0.0.1", 8082)
