using TablemarksCI
using Test
using Aqua

@testset "TablemarksCI.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(TablemarksCI)
    end

    @testset "Regression tests" begin
        using TablemarksCI: runbenchmarks
        runbenchmarks()
    end
end
