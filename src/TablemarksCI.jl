module TablemarksCI

using Compat
using Random
using Profile
using Pkg, Markdown
using Serialization
using Base.Threads

export @track
@compat public runbenchmarks

function runbenchmarks(;
        project = dirname(pwd()), # run from test directory
        bench_project = joinpath(project, "bench"),
        bench_file = joinpath(bench_project, "runbenchmarks.jl"),
        primary = "dev",
        comparison = "main",
        workers = min(8, Sys.CPU_THREADS),
        )

    commands = Vector{Cmd}(undef, workers)
    projects = [tempname() for _ in 1:workers]
    channels = [tempname() for _ in 1:workers]
    # bench_projectfile = joinpath(bench_project, "Project.toml")
    # bench_projectfile_exists = isfile(bench_projectfile)
    julia_exe = joinpath(Sys.BINDIR, "julia")
    rfile = repr(bench_file)
    for i in 1:workers
        mkdir(projects[i])
        # bench_projectfile_exists && cp(bench_projectfile, joinpath(projects[i], "Project.toml"))
        cp(bench_project, projects[i], force=true)
        script = "using TablemarksCI: _runbenchmarks3; _runbenchmarks3($rfile, $(repr(channels[i])))"
        commands[i] = `$julia_exe --project=$(projects[i]) -e $script`
    end
    pkg_lock = ReentrantLock() # I'm not sure if Pkg can be used in multiple environments from multiple tasks at the same time
    data_lock = ReentrantLock() # I know this is not thread safe
    metadatas = Vector{Tuple{Symbol, Int, String}}[]
    datas = Vector{Vector{Float64}}[]

    revs = shuffle!(repeat([primary, comparison], 2))
    worker_pool = Channel{Int}(workers)
    put!.(Ref(worker_pool), 1:workers)

    @sync for rev in revs
        worker = take!(worker_pool)
        println("A")
        Pkg.activate(projects[worker], io=devnull)
        println("B")
        if rev == "dev"
            Pkg.develop(PackageSpec(path=project), io=devnull)
        else
            Pkg.add(PackageSpec(path=project, rev=rev), io=devnull)
        end
        Pkg.instantiate(io=devnull)
        println("C")
        begin # @async begin
            println("D")
            println(commands[worker])
            run(commands[worker], wait=true)

            println("F")
            println(channels[worker])
            println(isfile(channels[worker]))
            m, d = deserialize(channels[worker])
            println("Pass")
            push!(metadatas, m)
            push!(datas, d)
            # TODO: make this data transfer more efficient and/or give better errors
            allequal(metadatas) || error("Metadata mismatch")
            allequal(length.(d) for d in datas) || error("Data length mismatch")
            println("F")
            put!(worker_pool, worker)
        end
    end

    return metadatas, datas
end
function runbenchmarks_pkg()
    runbenchmarks(project = dirname(Pkg.project().path))
end

const METADATA3 = Tuple{Symbol, Int, String}[]
const DATA2 = Vector{Float64}[]
macro track(expr)
    push!(DATA2, Float64[])
    i = lastindex(DATA2)
    push!(METADATA3, (__source__.file, __source__.line, string(expr)))
    :(push!(DATA2[$i], Float64($(esc(expr)))))
end
function _runbenchmarks3(file, destination)
    include(file)
    println("AAAA")
    serialize(destination, (METADATA3, DATA2))
    println(destination)
    println(isfile(destination))
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