using WGLMakie, Bonito
using Colors, ImageTransformations, Markdown
using Bonito: styled_slider

folder = joinpath(@__DIR__, "simulation")

volume_frames = map(readdir(folder)) do file
    open(joinpath(folder, file)) do io
        data = Array{Float32, 3}(undef, 130, 258, 65)
        read!(io, data)
        return data
    end
end

struct Flip <: Bonito.WidgetsBase.AbstractWidget{Bool}
    label::String
    value::Observable{Bool}
end
Flip(label) = Flip(label, Observable(false))
# Implement interface for Flip to work with offline mode
Bonito.is_widget(::Flip) = true
Bonito.value_range(flip::Flip) = (true, false)
Bonito.update_value!(flip::Flip, value) = (flip.value[] = value)

function Bonito.jsrender(flip::Flip)
    return DOM.input(
        type = "button",
        value = flip.label,
        onclick = js"{
            const value = this.last_value;
            $(flip.value).notify(!value);
            this.last_value = !value;
        }";
        class="p-1 rounded m-2"
    )
end

function handler(s, r)
    sl = Bonito.Slider(1:64)
    absorption = Bonito.Slider(range(1f0, stop=10f0, step=0.1))
    flip_colormap = Flip("flip colormap")
    absorption.value[] = 5
    v = map(sl) do idx
        # make volumes a bit smaller!
        restrict(volume_frames[idx])
    end
    clims = (8, 12)
    cmapa = RGBAf.(to_colormap(:thermal), 1.0)
    cmap1 = vcat(fill(RGBAf(0,0,0,0), 20), cmapa)
    cmap2 = vcat(cmapa, fill(RGBAf(0,0,0,0), 20))
    cmap = map(flip_colormap) do x
        return x ? copy(cmap1) : copy(cmap2)
    end

    scene = volume(v;
        colorrange=clims, algorithm=:absorption, absorption=absorption, colormap=cmap, show_axis=false,
        resolution=(600, 600))

    markdown = md"""

    # Ocean Simulation

    Simulation of instability of a horizontal density gradient in a rotating channel using 256x512x128 grid points running on a GPU. A similar process called baroclinic instability acting on basin-scale temperature gradients fills the oceans with eddies, especially in regions with large temperature gradients. These eddies are the primary way the ocean transports heat, carbon dioxide, organic matter, and nutrients on a large scale.

    Simulation created with [Oceananigans.jl](https://github.com/CliMA/Oceananigans.jl/) which is part of the [CliMA](https://github.com/CliMA) project.

    [source code](https://github.com/SimonDanisch/Bonito.jl/blob/master/examples/oceananigans.jl)

    ---

    absorption: $(styled_slider(absorption, absorption.value))
    time: $(styled_slider(sl, sl.value))

    $(flip_colormap)

    $(scene)

    """
    dom = DOM.div(Bonito.MarkdownCSS, Bonito.Styling, Bonito.TailwindCSS, markdown)
    # return dom
    return Bonito.record_state_map(s, dom).dom
end

# Either serve
# app = Bonito.Server(handler, "0.0.0.0", 8083)

export_path = "dev/WGLDemos/oceananigans/"
# or export to e.g. github IO
Bonito.export_standalone(handler, export_path, clear_folder=true)
