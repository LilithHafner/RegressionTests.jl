using TestPackage
using RegressionTests
using Test

@testset "Correctness" begin
    @test my_sum([1,2,3]) ≈ 6
end

@testset "Performance" begin
    runbenchmarks()
end
