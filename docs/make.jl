using TablemarksCI
using Documenter

DocMeta.setdocmeta!(TablemarksCI, :DocTestSetup, :(using TablemarksCI); recursive=true)

makedocs(;
    modules=[TablemarksCI],
    authors="Lilith Orion Hafner <lilithhafner@gmail.com> and contributors",
    repo="https://github.com/LilithHafner/TablemarksCI.jl/blob/{commit}{path}#{line}",
    sitename="TablemarksCI.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://LilithHafner.github.io/TablemarksCI.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/LilithHafner/TablemarksCI.jl",
    devbranch="main",
)
