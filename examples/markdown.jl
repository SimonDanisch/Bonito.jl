using Markdown
using Bonito, Observables
using WGLMakie

app = App() do
    cmap_button = Button("change colormap")
    algorithms = ["mip", "iso", "absorption"]
    algorithm_drop = Dropdown(algorithms)

    data_slider = Slider(LinRange(1f0, 10f0, 100))
    iso_value = Slider(LinRange(0f0, 1f0, 100))
    N = 100
    slice_idx = Slider(1:N)

    signal = map(data_slider.value) do α
        a = -1; b = 2
        r = LinRange(-2, 2, N)
        z = ((x,y) -> x + y).(r, r') ./ 5
        me = [z .* sin.(α .* (atan.(y ./ x) .+ z.^2 .+ pi .* (x .> 0))) for x=r, y=r, z=r]
        return me .* (me .> z .* 0.25)
    end

    slice = map(signal, slice_idx) do x, idx
        view(x, :, idx, :)
    end

    fig = Figure(; size=(900, 400))

    vol = volume(fig[1,1], signal; algorithm=map(Symbol, algorithm_drop.value), isovalue=iso_value.value, axis=(;show_axis=false))

    colormaps = collect(Makie.all_gradient_names)
    cmap = map(cmap_button) do click
        return colormaps[rand(1:length(colormaps))]
    end

    heat = heatmap(fig[1, 2], slice, colormap=cmap)

    # Conditionally show ISO value slider only when algorithm is "iso"
    iso_control = map(algorithm_drop.value) do alg
        if alg == "iso"
            return DOM.div("ISO value: ", iso_value)
        else
            return DOM.div()
        end
    end

    dom = md"""
    # Interactive 3D Volume Visualization

    This example demonstrates **Bonito.jl**'s ability to combine markdown content with interactive widgets and 3D visualizations using WGLMakie.

    ## About This Demo

    Below you'll find interactive controls that manipulate a 3D volume rendering in real-time. This showcases:

    * Reactive programming with `Observable`s
    * Integration between markdown and Julia widgets
    * Real-time 3D visualization with WGLMakie
    * Clean, styled presentation using Bonito's layout system

    ## Visualization Controls

    Use the controls below to explore the 3D volume data:

    **Data Parameter**: Adjust the mathematical function generating the volume data

    $(DOM.div("Data parameter: ", data_slider))

    **Algorithm**: Choose the volume rendering algorithm

    $(DOM.div("Algorithm: ", algorithm_drop))

    $(iso_control)

    **Y-Slice**: Select which slice to display in the heatmap

    $(DOM.div("Y slice: ", slice_idx))

    **Colormap**: Randomize the heatmap colors

    $(cmap_button)

    ---

    ## The Visualization

    $(fig)

    ---

    ## Markdown Features

    Bonito supports GitHub-flavored Markdown including:

    1. **Formatted text**: *italic*, **bold**, and `inline code`
    2. **LaTeX equations** via KaTeX
    3. **Tables** for structured data
    4. **Embedded widgets** as shown above

    ### LaTeX Support

    Bonito renders beautiful mathematical expressions:

    ```latex
    \int_{-\infty}^{\infty} e^{-x^2} dx = \sqrt{\pi}

    \mathbf{A} = \begin{pmatrix}
    a_{11} & a_{12} \\
    a_{21} & a_{22}
    \end{pmatrix}
    ```

    ### Tables

    | Feature        | Status        | Priority |
    | -------------- |:-------------:| --------:|
    | 3D Rendering   | ✓ Implemented | High     |
    | Interactivity  | ✓ Implemented | High     |
    | Styling        | ✓ Implemented | Medium   |

    > **Note**: This entire page is generated from a single Julia file, combining markdown prose with interactive computational content!
    """
    # Create a styled container with max-width and centered content
    container_style = Styles(
        "max-width" => "900px",
        "margin" => "0 auto",
        "padding" => "2rem",
        "background-color" => "#ffffff",
        "box-shadow" => "0 1px 3px rgba(0, 0, 0, 0.1)",
        "border-radius" => "8px",
        "line-height" => "1.6"
    )

    content = DOM.div(Bonito.MarkdownCSS, Bonito.Styling, dom; style=container_style)

    # Wrap in outer container for centering
    outer_style = Styles(
        "background-color" => "#f5f5f5",
        "min-height" => "100vh",
        "padding" => "2rem 1rem"
    )

    return DOM.div(content; style=outer_style)
end
