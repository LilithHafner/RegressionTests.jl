using TestPackage
using RegressionTests
using Test

@testset "Correctness" begin
    @test my_sum([1,2,3,4]) ≈ 10
    @test my_prod([1,2,3,4]) ≈ 24
end

@testset "Performance" begin
    runbenchmarks()
end
