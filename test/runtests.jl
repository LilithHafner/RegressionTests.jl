using RegressionTests
using Test
using Aqua
using Pkg

@testset "RegressionTests.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(RegressionTests, deps_compat=false)
    end

    @testset "Correctness" begin
        @test RegressionTests.are_very_different(vcat(trues(3), falses(3)), vcat(1:3, 100:100:300))
        @test RegressionTests.are_very_different(vcat(trues(3), falses(3)), vcat(1:3, 101:103))
        @test RegressionTests.are_very_different(vcat(trues(3), falses(3)), vcat(1:3, 101:103), increase=true)
        @test !RegressionTests.are_very_different(vcat(trues(3), falses(3)), vcat(1:3, 101:103), increase=false)
        @test !RegressionTests.are_very_different(vcat(trues(3), falses(3)), 1:6)
        @test !RegressionTests.are_very_different(vcat(trues(3), falses(3)), (1:6) .+ 10000)
        @test RegressionTests.are_very_different(vcat(trues(3), falses(3)), vcat(fill(pi, 3), fill(nextfloat(float(pi)), 3)))
        @test !RegressionTests.are_very_different(vcat(trues(3), falses(3)), vcat(fill(float(pi), 6)))
    end

    # TODO: make this work when it comes after "Example usage" as well.
    @testset "Regression tests" begin
        # RegressionTests.test(skip_unsupported_platforms=true)
    end

    if RegressionTests.is_platform_supported()
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
                    if get(ENV, "CI", "false") == "true"
                        run(`git config --global init.defaultBranch main`)
                    end
                    run(`git init`)
                    if get(ENV, "CI", "false") == "true"
                        run(`git config user.email "CI@example.com"`)
                        run(`git config user.name "CI"`)
                    end
                    run(`git add .`)
                    run(`git commit -m "Initial content"`)
                    old_src = read(src_file, String)
                    new_src = replace(old_src, "my_sum(x) = sum(x)" => "my_sum(x) = sum(Float64.(x))")
                    write(src_file, new_src)
                    # t = @elapsed changes = runbenchmarks(project = ".") # Fail
                    # println("Runtime for positive runbenchmarks: $t")
                    # @test !isempty(changes)

                    # This test is allowed to fail because we currently do not suppress inter-tracked-result interactions
                    # The `isempty(runbenchmarks(project = "."))` test below is a false positive test that should always pass.
                    # It's not catastrophic to get these my_prod false positives, becasue there are also true positives being reported.
                    # @test !any(occursin("my_prod", c.expr) for c in changes) # Those didn't change [This is the a false positive test]

                    # @test any(occursin("my_sum", c.expr) for c in changes) # This did change
                    # println.(changes)
                    run(`git add $src_file`)
                    run(`git commit -m "Introduce regression"`)
                    # t = @elapsed @test isempty(runbenchmarks(project = ".")) # Pass
                    # println("Runtime for negative runbenchmarks 1: $t")
                    t = @elapsed @test isempty(runbenchmarks(project = ".", primary="main", comparison="main"))
                    println("Runtime for negative runbenchmarks 2: $t")
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
    end
end
