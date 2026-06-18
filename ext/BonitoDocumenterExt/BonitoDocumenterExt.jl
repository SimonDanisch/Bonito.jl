module BonitoDocumenterExt

using Bonito
using Bonito: DOM
import Documenter
import MarkdownAST
const MA = MarkdownAST
import Markdown
import Dates
using Base64: base64encode, base64decode

# ---------------------------------------------------------------------------
# Documenter output format. Pass it to `makedocs(format = ...)` via the public
# `Bonito.DocumenterBonito(...)` entry point (a stub defined in Bonito itself).
# ---------------------------------------------------------------------------

"""
    BonitoFormat(; kwargs...)

Backing struct for [`Bonito.DocumenterBonito`](@ref). Keyword arguments:

- `repo`: full repository URL (e.g. `"github.com/SimonDanisch/Bonito.jl"`),
  used for the GitHub link and per-page "Edit this page" links.
- `devbranch`: branch used for edit links (default `"master"`).
- `devurl`: development subfolder name (default `"dev"`).
- `version`: label shown in the navbar version switcher (default: none).
- `logo`: path/URL of the navbar logo image (default: none).
- `home_page`: source file that should use the landing layout (default `"index.md"`).
- `home`: a NamedTuple describing the hero/landing page (see `home.jl`); when
  `nothing` (the default) every page uses the standard doc layout.
- `description`: site description (currently informational).
"""
Base.@kwdef struct BonitoFormat <: Documenter.Writer
    repo::String = ""
    devbranch::String = "master"
    devurl::String = "dev"
    version::String = ""
    logo::Union{Nothing, String} = nothing
    home_page::String = "index.md"
    home::Any = nothing
    description::String = ""
    ansicolor::Bool = true
    # Folder of blog posts (relative to the docs root, e.g. `"blog"`); each
    # subfolder is one post (`post.xml` + `post.md` + `images/`). `nothing`
    # disables the blog. See `blog.jl`.
    blog::Union{Nothing, String} = nothing
end

Bonito.DocumenterBonito(; kwargs...) = BonitoFormat(; kwargs...)

# Hook into Documenter's format dispatch.
abstract type BonitoFormatSelector <: Documenter.FormatSelector end
Documenter.Selectors.order(::Type{BonitoFormatSelector}) = 0.0
Documenter.Selectors.matcher(::Type{BonitoFormatSelector}, fmt, _) = isa(fmt, BonitoFormat)
Documenter.Selectors.runner(::Type{BonitoFormatSelector}, fmt, doc) = render(doc, fmt)

builddir(doc) = isabspath(doc.user.build) ? doc.user.build : joinpath(doc.user.root, doc.user.build)

@static if :writer_supports_ansicolor in names(Documenter; all = true)
    Documenter.writer_supports_ansicolor(::BonitoFormat) = true
end

include("expanders.jl")
include("domify.jl")
include("layout.jl")
include("home.jl")
include("blog.jl")
include("writer.jl")

end # module
