module TablemarksCI

using Compat
using Random
using Profile
using JuliaSyntax
using Pkg, Markdown

export @b_AUTO, @b
@compat public runbenchmarks

include("juliasyntax.jl")
include("b_auto.jl")

function runbenchmarks(;
        project = dirname(pwd()), # run from test directory
        bench_project = joinpath(project, "bench"),
        bench_file = joinpath(bench_project, "runbenchmarks.jl"),
        fix_auto = !CI[],
        primary = "dev",
        comparison = "main",
        threads = min(8, Sys.CPU_THREADS),
        )


    projects = [tempname() for _ in 1:threads]
    channels = [tempname() for _ in 1:threads]
    input = tempname()
    mkdir.(projects)
    bench_projectfile = joinpath(bench_project, "Project.toml")
    isfile(bench_projectfile) && cp.(Ref(bench_projectfile), projects)

    function setup(rev, i)
        Pkg.activate(projects[i])
        if rev == "dev"
            Pkg.develop(PackageSpec(path=project))
        else
            Pkg.pin(PackageSpec(name="TablemarksCI", rev=rev))
        end
    end

    setup(comparison, 1)
    cmd = "using TablemarksCI: skim; skim($(repr(channels[i])), $(repr(file)))"
    println(cmd)
    run(`julia --project $(projects[1]) -e $cmd`)
    cp(channels[1], input)
    setup(primary, 1)
    cmd = "using TablemarksCI: skim; skim($(repr(channels[i])), $(repr(file))$(fix_auto ? ", "*repr(input) : ""))"
    println(cmd)
    run(`julia --project $(projects[1]) -e $cmd`)


    cp(project, dirs[1])

    cd(dirs1) do
        run(`julia --project -e $cmd`)
    end
    ids = reinterpret(UInt128, read(temp))
    println.(repr.(ids))
end
function runbenchmarks_pkg()
    runbenchmarks(project = dirname(Pkg.project().path))
end

const SKIM = Ref(false)
const AUTO_ID_COUNT = Ref(0)
const IDS = Set{UInt128}()
const FILES = Set{Symbol}()
function log_id(id)
    id128 = UInt128(id)
    if id128 in IDS
        error("Duplicate id: $id")
    end
    push!(IDS, id128)
end
macro b(id, args...)
    push!(FILES, __source__.file)
    if id isa QuoteNode
        id = id.value
    end
    if id isa Symbol && lowercase(string(id) )=== "auto"
        # TODO Throw on non-skim and non-ci
        AUTO_ID_COUNT[] += 1
    elseif id isa Base.BitUnsigned64
        log_id(id)
    elseif id isa Expr && id.head === :macrocall && id.args[1] === Core.var"@uint128_str" && id.args[2] === nothing && id.args[3] isa String
        log_id(Base.parse(UInt128, id.args[3]))
    else
        println(id)
        println(typeof(id))
        error("Invalid id: $id")
    end
end

const CI = get(ENV, "CI", "false") != "false"
function skim(report::IO, source, fix_auto)
    include(source) # TODO: lint for benchmarks that are not gated by @b
    if AUTO_ID_COUNT[] != 0
        if fix_auto
            id_space = max(2(length(IDS) + AUTO_ID_COUNT[]), maximum(IDS))
            T = id_space <= typemax(UInt32) ? UInt32 : id_space <= typemax(UInt64) ? UInt64 : UInt128
            function id_source()
                x = rand(T)
                while UInt128(x) in IDS
                    x = rand(T)
                end
                push!(IDS, UInt128(x))
                repr(x)
            end
            transform_file2.(id_source, FILES)
        else
            error("`:auto` must be replaced with randomly generated ids")
        end
    end
    write.(report, sort!(collect(IDS)))
    flush(report)
end

# TODO: make this weak dep and/or move it to a separate package that lives in default environments
function __init__()
    Pkg.REPLMode.SPECS["package"]["bench"] = Pkg.REPLMode.CommandSpec(
        "bench", # Long name
        nothing, # short name
        runbenchmarks_pkg, # API
        true, # should_splat
        Pkg.REPLMode.ArgSpec(0 => 0, Pkg.REPLMode.parse_package), # Arguments
        Dict{String, Pkg.REPLMode.OptionSpec}(), # Options
        nothing, # Completions
        "run regression tests for packages", # Description
        # Help
        md"""
            bench

        Run the benchmarks for package `pkg`. This is done by running the file
        `bench/runbenchmarks.jl` in the package directory. The `startup.jl` file is
        disabled during benchmarking unless julia is started with `--startup-file=yes`.""")
end

"""
    differentiate(f, g)

Determine if `f()` and `g()` have different distributions.

Returns `false` if `f` and `g` have the same distribution and usually returns `true` if
they have different distributions.

Properties

- If `f` and `g` have the same distribution, the probability of a false positive is `1e-10`.
- If `f` and `g` have distributions that differ* by at least `.05`, then the probability of
    a false negative is `.05`.
- If `f` and `g` have the same distribution, `f` and `g` will each be called 53 times, on
    average
- `f` and `g` will each be called at most 300 times.

The difference between distributions is quantified as the integral from 0 to 1 of
`(cdf(g)(invcdf(f)(x)) - x)^2` where `cdf` and `invcdf` are higher order functions that
compute the cumulative distribution function and inverse cumulative distribution function,
respectively.

More generally, for any `k > .025`, `recall` loss is according to empirical estimation,
at most `max(1e-4, 20^(1-k/.025))`. So, for example, a regression with `k = .1`, will be
escape detection at most 1 out of 8000 times.
"""
function differentiate(f, g)
    X = (0, 45, 75, 120, 300, 300)
    Y = (0, .005, .007, .008, .014)
    data = Vector{Float64}(undef, 2*X[2])
    for i in 2:5
        x0 = 2X[i-1]
        n = X[i]-X[i-1]
        for j in 1:n
            data[x0+j] = reinterpret(Float64, reinterpret(UInt64, f()) | 0x01)
            data[x0+n+j] = reinterpret(Float64, reinterpret(UInt64, g()) & ~UInt64(1))
        end
        sort!(data) # A sorting dominated workload ?!?!?
        sum = 0
        err = 0
        for j in eachindex(data)
            sum += Bool(reinterpret(UInt64, data[j]) & 0x01)
            delta = 2sum - j
            err += delta^2
        end
        @assert sum === X[i]
        err < (Y[i]*X[i]^3)*4+X[i] && return false
        resize!(data, 2X[i+1])
    end
    return true
end

end