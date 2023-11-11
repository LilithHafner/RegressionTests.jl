using TablemarksCI
using Test
using Aqua
using StableRNGs

@testset "TablemarksCI.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(TablemarksCI)
    end

    @testset "Transformations" begin
        dir = joinpath((@__DIR__), "example_files")
        names = [x[1:end-3] for x in readdir(dir) if endswith(x, ".jl") && !endswith(x, "_r.jl")]
        @test names ==["one", "two"]
        temp = tempname()
        filter = r"0x[0-9a-fA-F]+" => "0x"
        for name in names
            cp(joinpath(dir, name*".jl"), temp, force=true)
            TablemarksCI.transform_file(temp, rng=StableRNG(1729))
            actual = read(temp, String)
            expected = read(joinpath(dir, name * "_r.jl"), String)
            @test actual == expected

            cp(joinpath(dir, name*".jl"), temp, force=true)
            @test_throws LoadError include(temp)
            actual = read(temp, String)
            @test actual != expected # rngs don't align
            @test replace(actual, filter) == replace(expected, filter)
        end
    end
end
