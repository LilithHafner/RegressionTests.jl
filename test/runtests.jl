using RegressionTests
using Test
using Aqua
using Pkg

@testset "RegressionTests.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(RegressionTests, deps_compat=false)
    end

    @testset "Example usage" begin
        regression_tests_path = dirname(dirname(@__FILE__))
        package = Pkg.project().path
        cd(joinpath(dirname(@__FILE__), "TestPackage")) do
            backup = tempname()
            src_file = joinpath("src", "TestPackage.jl")
            cp(src_file, backup)
            try
                Pkg.activate("bench")
                Pkg.add(path=regression_tests_path)
                run(`git init`)
                run(`git add .`)
                run(`git commit -m "Initial content" --author "CI <>"`)
                old_src = read(src_file, String)
                new_src = replace(old_src, "my_sum(x) = sum(x)" => "my_sum(x) = sum(Float64.(x))")
                write(src_file, new_src)
                changes = runbenchmarks(project = ".") # Fail
                @test !isempty(changes)
                @test !any(occursin("my_prod", c.expr) for c in changes) # Those didn't change
                @test any(occursin("my_sum", c.expr) for c in changes) # This did change
                println.(changes)
                run(`git add $src_file`)
                run(`git commit -m "Introduce regression" --author "CI <>"`)
                @test isempty(runbenchmarks(project = ".")) # Pass
                # TODO: handle this case well
                # TODO: track the runtime of these runbenchmark calls... but we can't use RegressionTests.jl because that would be too slow.
            finally
                Pkg.activate(package)
                if basename(pwd()) == "TestPackage" # Just double checking before we delete the git repo...
                    rm(".git", recursive=true, force=true)
                else
                    println("Woah!! Something strange happened")
                end
                cp(backup, src_file, force=true)
            end
        end
    end

    @testset "Regression tests" begin
        RegressionTests.test()
    end
end
