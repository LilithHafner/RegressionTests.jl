using Pkg
project = dirname(@__DIR__)
rev = "main"
try
    Pkg.add(url=project, rev=rev)
catch
    println("Ran `Pkg.add(path=project, rev=rev)`")
    println("project = ", project)
    println("rev = ", rev)
    println(readdir(project))
end

# using RegressionTests
# using Test
# using Aqua

# @testset "RegressionTests.jl" begin
#     @testset "Code quality (Aqua.jl)" begin
#         Aqua.test_all(RegressionTests, deps_compat=false)
#     end

#     @testset "Example usage" begin
#         regression_tests_path = dirname(dirname(@__FILE__))
#         package = Pkg.project().path
#         cd(joinpath(dirname(@__FILE__), "TestPackage")) do
#             backup = tempname()
#             src_file = joinpath("src", "TestPackage.jl")
#             cp(src_file, backup)
#             try
#                 Pkg.activate("bench")
#                 Pkg.add(path=regression_tests_path)
#                 println("A")
#                 if get(ENV, "CI", "false") == "true"
#                     run(`git config --global init.defaultBranch main`)
#                 end
#                 println("B")
#                 run(`git init`)
#                 println("C")
#                 if get(ENV, "CI", "false") == "true"
#                     run(`git config user.email "CI@example.com"`)
#                     run(`git config user.name "CI"`)
#                 end
#                 run(`git add .`)
#                 println("D")
#                 run(`git commit -m "Initial content"`)
#                 println("E")
#                 old_src = read(src_file, String)
#                 new_src = replace(old_src, "my_sum(x) = sum(x)" => "my_sum(x) = sum(Float64.(x))")
#                 write(src_file, new_src)
#                 println("F")
#                 changes = runbenchmarks(project = ".") # Fail
#                 println("G")
#                 @test !isempty(changes)
#                 @test !any(occursin("my_prod", c.expr) for c in changes) # Those didn't change
#                 @test any(occursin("my_sum", c.expr) for c in changes) # This did change
#                 println.(changes)
#                 run(`git add $src_file`)
#                 run(`git commit -m "Introduce regression"`)
#                 @test isempty(runbenchmarks(project = ".")) # Pass
#                 # TODO: handle this case well
#                 # TODO: track the runtime of these runbenchmark calls... but we can't use RegressionTests.jl because that would be too slow.
#             finally
#                 Pkg.activate(package)
#                 if basename(pwd()) == "TestPackage" # Just double checking before we delete the git repo...
#                     rm(".git", recursive=true, force=true)
#                 else
#                     println("Woah!! Something strange happened")
#                 end
#                 cp(backup, src_file, force=true)
#             end
#         end
#     end

#     @testset "Regression tests" begin
#         RegressionTests.test()
#     end
# end
