using CSV, Shapefile
using JSServe, WGLMakie, AbstractPlotting, Markdown
using JSServe.DOM
using JSServe: styled_slider
using AbstractPlotting.MakieLayout

read_data(path) = open(path) do io
    # skip first line since it contains an invalid comment
    readuntil(io, "\n")
    CSV.File(io, delim=';')
end

function normalize_names(x)
    no_umlaut = replace(x, r"[üöä]" => (x)-> Dict("ü" => "ue", "ö"=>"ae", "ä"=>"oe")[x])
    bb = replace(no_umlaut, "Brandenburg/Berlin" => "Berlin")
    if any(y-> occursin(y, bb), ("Hamburg", "Bremen", "Niedersachsen"))
        return "Niedersachsen"
    end
    return bb
end

data_dir = joinpath(@__DIR__, "data")
mkdir(data_dir)
data_temp_path = joinpath(data_dir, "temperature.txt")
data_prec_path = joinpath(data_dir, "precipitation.txt")
download("https://opendata.dwd.de/climate_environment/CDC/regional_averages_DE/annual/air_temperature_mean/regional_averages_tm_year.txt", data_temp_path)
download("https://opendata.dwd.de/climate_environment/CDC/regional_averages_DE/annual/precipitation/regional_averages_rr_year.txt", data_prec_path)

temp_data = read_data(data_temp_path)
prec_data = read_data(data_prec_path)

url_gadm = "https://biogeo.ucdavis.edu/data/gadm3.6/shp/gadm36_DEU_shp.zip"
shape_path = joinpath(data_dir, "gadm36_DEU_1.shp")
shape_zip = joinpath(data_dir, "gadm36_DEU_1.zip")
download(url_gadm, shape_zip)
run(`unzip $shape_zip -d $data_dir`)
tbl_states = Shapefile.Table(shape_path)

states = map(normalize_names, tbl_states.NAME_1)
states_geom_map = Dict(zip(map(normalize_names, tbl_states.NAME_1), tbl_states.NAME_1))
states_sym = propertynames(temp_data)[3:end]
statenames_to_sym = Dict(zip(normalize_names.(string.(states_sym)), states_sym))

states_to_plot = filter(states) do state
    haskey(statenames_to_sym, state)
end

function data_extrema(data)
    combinations = [(s, i) for s in states_to_plot, i in 1:length(data)]
    return extrema(map(combinations) do (state, idx)
        return data[idx][statenames_to_sym[state]]
    end)
end

function visualize_data(scene, data, cmap, colorrange, s)
    colormap = to_colormap(cmap)
    colors = map(s) do idx
        map(states_to_plot) do state
            datapoint = data[idx][statenames_to_sym[state]]
            return AbstractPlotting.interpolated_getindex(colormap, datapoint, colorrange)
        end
    end

    polys = map(states_to_plot) do state
        idx = findfirst(x-> x.NAME_1 == states_geom_map[state], tbl_states)
        return tbl_states[idx].Geometry
    end
    # Plot each state individually, so we can update one color per state
    for i in 1:length(states_to_plot)
        poly!(scene, polys[i], color=lift(x-> x[i], colors))
    end
    return scene
end
fig = Figure()
ax = fig[1,1] = Axis(fig)

fig = Figure(resolution = (900, 700))
to_plot = (
    (1, "Temperatur", temp_data, :heat),
    (2, "Regen", prec_data, :blues))
s = Observable(1)
foreach(to_plot) do (i, title, data, cmap)
    colorrange = data_extrema(data)
    ax = fig[1, i] = Axis(fig; title=title)
    hidedecorations!(ax, grid = false)
    visualize_data(ax, data, cmap, colorrange, s)
    layout[2, i] = Colorbar(fig, colormap=cmap, limits=colorrange, vertical=false, height=30, flipaxisposition=false, labelvisible=false,
    ticklabelalign=(:center, :top), ticksize=5)
    return
end
display(fig)

function handler(session, req)
    s = JSServe.Slider(1:length(temp_data))

    scene, layout = layoutscene(20, resolution = (900, 700))
    to_plot = (
        (1, "Temperatur", temp_data, :heat),
        (2, "Regen", prec_data, :blues))

    foreach(to_plot) do (i, title, data, cmap)
        colorrange = data_extrema(data)
        ax = layout[1, i] = LAxis(scene; title=title)
        hidedecorations!(ax, grid = false)
        visualize_data(ax, data, cmap, colorrange, s)
        layout[2, i] = LColorbar(scene, colormap=cmap, limits=colorrange, vertical=false, height=30, flipaxisposition=false, labelvisible=false,
        ticklabelalign=(:center, :top), ticksize=5)
        return
    end

    year = map(idx-> temp_data[idx].Jahr, s)

    markdown = md"""
    # Durchschnitts Temperatur per Bundesland

    ## Reise vom Jahr 1881 bis 2019
    $(styled_slider(s, year))

    $(scene)

    [Quelle: Deutscher Wetterdienst](https://opendata.dwd.de/climate_environment/CDC/regional_averages_DE/annual/)

    [Quellcode für Visualisierung](https://github.com/SimonDanisch/JSServe.jl/blob/master/examples/german_clima.jl)
    """

    dom = DOM.div(JSServe.MarkdownCSS, JSServe.TailwindCSS, JSServe.Styling, markdown)
    # return dom
    return JSServe.record_state_map(session, dom).dom
end

# Either export standalone
JSServe.export_standalone(handler, "dev/WGLDemos/german_heat", clear_folder=true)

# Or serve!
# app = JSServe.Server(handler, "0.0.0.0", 8082)
