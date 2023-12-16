using CSV, Shapefile
using Bonito, WGLMakie, Markdown
using Downloads: download
import Bonito.TailwindDashboard as D
using GeoInterfaceMakie
GeoInterfaceMakie.@enable Shapefile.Polygon

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
tbl_states = collect(Shapefile.Table(shape_path))

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
            return Makie.interpolated_getindex(colormap, datapoint, colorrange)
        end
    end

    polys = map(states_to_plot) do state
        idx = findfirst(x-> x.NAME_1 == states_geom_map[state], tbl_states)
        return tbl_states[idx].geometry
    end
    # Plot each state individually, so we can update one color per state
    for i in 1:length(states_to_plot)
        poly!(scene, polys[i], color=lift(x-> x[i], colors))
    end
    return scene
end

app = App() do session
    fig = Figure(resolution=(900, 700))
    to_plot = (
        (1, "Temperatur", temp_data, :heat),
        (2, "Regen", prec_data, :blues))
    s = Bonito.Slider(1:length(temp_data))

    for (i, title, data, cmap) in to_plot
        colorrange = data_extrema(data)
        ax = Axis(fig[1, i]; title=title)
        hidedecorations!(ax, grid=false)
        visualize_data(ax, data, cmap, colorrange, s)
        fig[2, i] = Colorbar(fig, colormap=cmap, limits=colorrange, vertical=false, height=30, labelvisible=false)
    end

    year = map(idx-> temp_data[idx].Jahr, s)

    markdown = md"""
    # Durchschnitts Temperatur per Bundesland

    ## Reise vom Jahr 1881 bis 2019
    $(styled_slider(s, year))

    $(fig)

    [Quelle: Deutscher Wetterdienst](https://opendata.dwd.de/climate_environment/CDC/regional_averages_DE/annual/)

    [Quellcode für Visualisierung](https://github.com/SimonDanisch/Bonito.jl/blob/master/examples/german_clima.jl)
    """

    dom = DOM.div(Bonito.MarkdownCSS, Bonito.TailwindCSS, Bonito.Styling, markdown)
    # return dom
    return Bonito.record_states(session, dom)
end;

# Either export standalone
mkpath("./dev/WGLDemos/")
Bonito.export_static("./dev/WGLDemos/german_heat.html", app)

# Or serve as a website!
# app = Bonito.Server(app, "0.0.0.0", 80)
