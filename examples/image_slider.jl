using Bonito, FileIO, Colors, Observables
using Bonito.DOM
using Bonito: App
Bonito.browser_display()
dir = mktempdir()
for i in 1:5
    save(joinpath(dir, "img$i.jpg"), rand(RGB{Colors.N0f8}, 200, 200))
end

app = App() do
    files = Bonito.Asset.(joinpath.(dir, filter(x-> endswith(x, ".jpg"), readdir(dir))))
    slider = Bonito.Slider(1:length(files))
    image_obs = Observable(first(files))
    img = DOM.img(src=image_obs, style="height: 200px;")
    on(slider) do idx
        image_obs[] = files[idx]
    end
    return DOM.div(slider, img)
end
