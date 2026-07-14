include("hyperscript_integration.jl")
include("markdown_integration.jl")
include("jsrender.jl")
include("observables.jl")
include("styling.jl")
# `keyed_list.jl` is NOT included here — it depends on `ES6Module`, which
# is defined later in `asset-serving/asset.jl`. It is included from
# `Bonito.jl` after asset-serving so all of its dependencies are loaded.
