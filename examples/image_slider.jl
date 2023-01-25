using Dashi, FileIO, Colors, Observables
using Dashi.DOM
using Dashi: App
Dashi.browser_display()
dir = mktempdir()
for i in 1:5
    save(joinpath(dir, "img$i.jpg"), rand(RGB{Colors.N0f8}, 200, 200))
end

app = App() do
    files = Dashi.Asset.(joinpath.(dir, filter(x-> endswith(x, ".jpg"), readdir(dir))))
    slider = Dashi.Slider(1:length(files))
    image_obs = Observable(first(files))
    img = DOM.img(src=image_obs, style="height: 200px;")
    on(slider) do idx
        image_obs[] = files[idx]
    end
    return DOM.div(slider, img)
end
