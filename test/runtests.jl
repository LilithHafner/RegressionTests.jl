using RegressionTests
using Test
using Aqua

@testset "RegressionTests.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(RegressionTests)
    end

    @testset "Regression tests" begin
        using RegressionTests
        runbenchmarks()
    end
end
