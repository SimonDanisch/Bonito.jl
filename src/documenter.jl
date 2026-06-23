"""
    DocumenterBonito(; kwargs...)

Documenter.jl output format that renders a documentation site with Bonito,
styled after VitePress. Pass it to the `format` keyword of `Documenter.makedocs`:

```julia
using Documenter, Bonito
makedocs(
    sitename = "MyPackage",
    format = Bonito.DocumenterBonito(; repo = "github.com/me/MyPackage.jl"),
    pages = [...],
)
```

The implementation lives in the `BonitoDocumenterExt` package extension and is only
available once `Documenter` is loaded. See the extension for the full list of
keyword arguments.
"""
function DocumenterBonito(args...; kwargs...)
    error("`Bonito.DocumenterBonito` requires Documenter.jl to be loaded. Run `using Documenter` (or add it to your docs environment) before calling it.")
end
