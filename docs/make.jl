using RegressionTests
using Documenter

DocMeta.setdocmeta!(RegressionTests, :DocTestSetup, :(using RegressionTests); recursive=true)

makedocs(;
    modules=[RegressionTests],
    authors="Lilith Orion Hafner <lilithhafner@gmail.com> and contributors",
    repo="https://github.com/LilithHafner/RegressionTests.jl/blob/{commit}{path}#{line}",
    sitename="RegressionTests.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://LilithHafner.github.io/RegressionTests.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/LilithHafner/RegressionTests.jl",
    devbranch="main",
)
