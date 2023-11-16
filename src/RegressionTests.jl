module RegressionTests

# Caller
using Random
using Pkg, Markdown
using Serialization

# Callie
using Serialization


# Caller
export runbenchmarks

# Callie
export @track, @group


# Caller

# TODO track precompilation time
# TODO track load time
# TODO track TTFX

"""
    runbenchmarks()

When called in `test/runtests.jl` while `pwd()` points to `test`, this function runs
the benchmarks in `bench/runbenchmarks.jl`.

There are some keyword arguments, but they are not public.
"""
function runbenchmarks(;
        project = dirname(pwd()), # run from test directory
        bench_project = joinpath(project, "bench"),
        bench_file = joinpath(bench_project, "runbenchmarks.jl"),
        primary = "dev",
        comparison = "main",
        workers = 15,#Sys.CPU_THREADS,
        )

    commands = Vector{Cmd}(undef, workers)
    projects = [tempname() for _ in 1:workers]
    channels = [tempname() for _ in 1:workers]
    filter_path = tempname()
    # bench_projectfile = joinpath(bench_project, "Project.toml")
    # bench_projectfile_exists = isfile(bench_projectfile)
    julia_exe = joinpath(Sys.BINDIR, "julia")
    rfile = repr(bench_file)
    for i in 1:workers
        mkdir(projects[i])
        # bench_projectfile_exists && cp(bench_projectfile, joinpath(projects[i], "Project.toml"))
        cp(bench_project, projects[i], force=true)
        script = "let; using RegressionTests, Serialization; RegressionTests.FILTER[] = deserialize($(repr(filter_path))); end; let; include($rfile); end; using RegressionTests, Serialization; serialize($(repr(channels[i])), (RegressionTests.STATIC_METADATA, RegressionTests.RUNTIME_METADATA, RegressionTests.DATA))"
        commands[i] = `$julia_exe --project=$(projects[i]) --handle-signals=no -e $script`
    end

    lens = 45, 75, 120, 300
    revs = shuffle!(repeat([primary, comparison], lens[1]))
    # TODO take a random shuffle that fails the first "plausibly different" test
    # so that things that are literally equal will never make it past the first round
    static_metadatas = Vector{Vector{Tuple{Symbol, Int, String}}}(undef, length(revs))
    runtime_metadatas = Vector{Vector{Int}}(undef, length(revs))
    datas = Vector{Vector{Float64}}(undef, length(revs))

    function setup_env(i, worker)
        rev = revs[i]
        Pkg.activate(projects[worker], io=devnull)
        if rev == "dev"
            Pkg.develop(PackageSpec(path=project), io=devnull)
        else
            Pkg.add(PackageSpec(path=project, rev=rev), io=devnull)
        end
        Pkg.instantiate(io=devnull)
    end
    function spawn_worker(worker, out, err)
        run(commands[worker], devnull, out, err; wait=false)
    end
    function store_results(i, worker)
        sm, rm, d = deserialize(channels[worker])
        static_metadatas[i] = sm
        runtime_metadatas[i] = rm
        datas[i] = d
    end

    # What's actually going on /\
    # Process management \/

    function do_work(log, inds)
        start_time = time()
        processes = Vector{Union{Nothing, Base.Process}}(undef, workers)
        work = Vector{Int}(undef, workers) # Which trial each worker is working on
        function nice_kill(worker)
            isassigned(processes, worker) || return
            p = processes[worker]
            # kill(processes[worker], Base.SIGKILL)
            kill(processes[worker], Base.SIGINT)
            @async begin sleep(.1); kill(p, Base.SIGTERM) end
            @async begin sleep(.2); kill(p, Base.SIGKILL) end
        end
        function _wait(n)
            for _ in 1:n
                take!(worker_pool)
            end
        end
        worker_pool = Channel{Int}(workers)
        for i in 1:workers; put!(worker_pool, i); end
        try
            for i in vcat(inds, fill(nothing, workers)) # Go through the loop an extra workers times to store the final results

                worker = take!(worker_pool) # Wait for available worker

                if isassigned(processes, worker) # Handle the data or error it produced (if any)
                    p = processes[worker]
                    @assert process_exited(p)
                    if !success(p)
                        # Error recovery path #1 entrypoint: error in benchmarking code
                        failure_time = time()
                        for w in 2:workers # Start to kill all other workers
                            w == worker || nice_kill(w)
                        end

                        wait_time = clamp(failure_time-start_time, .5, 5)
                        c = Condition()
                        @async begin sleep(wait_time); notify(c) end
                        @async begin wait(processes[1]); notify(c) end
                        wait(c)

                        if process_exited(processes[1]) && !success(processes[1])
                            # Yay! we got a failure in the process that is already
                            # piped into stdout and stderr
                            # 1 and worker are dead and all others have been `nice_kill`ed
                        else
                            # give up on waiting
                            nice_kill(1)
                            wait(processes[1]) # Don't want it's output to mangle the following error
                            # ERROR: Worker 7 running trial 9 failed.
                            # Worker 1 did not quickly reproduce the failure, reporting worker 7's logs below
                            # ===============================================================================
                            printstyled("ERROR:", color=:red)
                            println(" Worker $worker running trial $(work[worker]) failed.")
                            println("Worker 1 did not quickly reproduce the failure, reporting worker $worker's logs below")
                            println("===============================================================================")
                            @assert p.out === p.err
                            print(read(p.err, String))
                        end
                        # _wait(workers-1) # `worker` is already popped from the worker pool
                        return true # failure
                    end

                    store_results(work[worker], worker) # Fast

                    log(work[worker]) # Callback for progress reporting
                end

                i === nothing && continue # No more work to do

                work[worker] = i # Record which trial this worker is working on
                setup_env(i, worker) # Can't run in parallel
                out_err = if worker == 1 # Pipe only the first worker to stdout and stderr so that debug is legible
                    (stdout, stderr)
                else
                    x = IOBuffer()
                    (x, x)
                end
                processes[worker] = spawn_worker(worker, out_err...) # Keep a handle on the underlying process
                @async begin # This throwaway process will clean itself up and alert the centralized notification system once the underlying process exits
                    wait(processes[worker])
                    put!(worker_pool, worker)
                end
            end
        catch x
            if x isa InterruptException
                nice_kill.(1:workers)
                # _wait(workers-1) # Many workers could have already been waited for.
                return true # failure
            end
            rethrow() # Unexpected error (probably RegressionTests.jl's fault)
        end
        false # success
    end

    # Process management /\
    # What's actually going on \/

    inds = eachindex(revs)
    print("waiting for preliminary results...")
    filter = nothing
    original_runtime_metadata = nothing
    for i in 1:length(lens)
        serialize(filter_path, filter)
        num_completed = Ref(0)
        p = Pkg.project().path
        try
            do_work(inds) do j
                num_completed[] += 1
                num_completed[] == 1 && i == 1 && println(rpad("\r$(sum(length, datas[j])) tracked results", 34))
                print("\r$(num_completed[]) / $(length(inds))")
                flush(stdout)
            end && return nothing # do_work failed
        finally
            Pkg.activate(p, io=devnull) # More for the return than for errors.
        end
        println()
        # TODO: make these errors more descriptive and/or make the serialized data transfer more efficient
        allequal(static_metadatas) || error("Static metadata mismatch")
        allequal(runtime_metadatas) || error("Runtime metadata mismatch")
        allequal(length.(datas)) || error("Data length mismatch")

        i == 1 && (original_runtime_metadata = copy(runtime_metadatas[1]))

        plausibly_different = [are_different(revs, [datas[i][j] for i in eachindex(revs, datas)]) for j in eachindex(datas[1])]

        md = Int[]
        old_filter = filter === nothing ? trues(Int((length(last(runtime_metadatas))+length(plausibly_different))/2)) : filter
        data = reverse(plausibly_different)
        group_stack = Tuple{Int, Int}[]
        new_filter = BitVector()
        skip_depth = 0
        for m in original_runtime_metadata
            if skip_depth > 0
                if m < 0
                    skip_depth += 1
                elseif m == 0
                    skip_depth -= 1
                end
            elseif m == 0
                if isempty(group_stack)
                    push!(md, 0) # Close the group
                else
                    md_size, new_filter_size = pop!(group_stack)
                    resize!(md, md_size) # drop the @group metadata for the  group that is skipped
                    resize!(new_filter, new_filter_size) # Drop a bunch of falses
                    new_filter[end] = false # Correct the speculation to false
                end
            elseif m < 0
                if pop!(old_filter)
                    push!(new_filter, true) # Speculatively mark group as true
                    push!(group_stack, (length(md), length(new_filter)))
                    push!(md, m)
                else # The group was skipped
                    push!(new_filter, false)
                    @assert skip_depth == 0
                    skip_depth = 1
                end
            else @assert m > 0
                if pop!(old_filter)
                    if pop!(data)
                        push!(new_filter, true)
                        push!(md, m)
                        empty!(group_stack) # All these groups were correctly marked true
                    else
                        push!(new_filter, false)
                    end
                else
                    push!(new_filter, false)
                end
            end
        end
        @assert isempty(old_filter)
        append!(new_filter, old_filter) # Append the remaining falses
        reverse!(new_filter) # Reverse so that we can pop from the end in subprocesses
        filter = new_filter

        runtime_metadatas .= Ref(md)
        for i in eachindex(datas)
            datas[i] = datas[i][plausibly_different] # Drop the data that we know is equal
        end

        sc = count(plausibly_different)
        (sc == 0 || i == lastindex(lens)) && break
        println(sc, "/", length(plausibly_different), " tracked results are plausibly different. Running more trials for them")
        old_len = length(revs)
        append!(revs, shuffle!(repeat([primary, comparison], lens[i+1]-lens[i])))
        inds = old_len+1:length(revs)
        print("0/$(length(inds))")
        resize!(static_metadatas, length(revs))
        resize!(runtime_metadatas, length(revs))
        resize!(datas, length(revs))
    end

    # TODO throw on Inf or NaN
    # Note literal equality is fine because we use a stable sort and the order is random

    # Make regressions
    occurrences = zeros(Int, length(static_metadatas))
    for m in original_runtime_metadata
        m > 0 && (occurrences[m] += 1)
    end
    counts = zeros(Int, length(static_metadatas))
    changes = Vector{Change}(undef, length(datas[1]))
    changes_i = 0
    skip = 0
    for m in original_runtime_metadata
        m > 0 && (counts[m] += 1)
        if skip > 0
            if m < 0
                skip += 1
            elseif m == 0
                skip -= 1
            end
        elseif m < 0
            pop!(filter) || (skip = 1)
        elseif m > 0
            if pop!(filter)
                # A change!
                changes_i += 1
                changes[changes_i] = Change(
                    first(static_metadatas)[m]...,
                    counts[m],
                    occurrences[m],
                    [datas[i][changes_i] for i in eachindex(datas) if revs[i] == primary],
                    [datas[i][changes_i] for i in eachindex(datas) if revs[i] == comparison],
                )
            end
        end
    end

    return changes
end
function runbenchmarks_pkg()
    runbenchmarks(project = dirname(Pkg.project().path))
end

struct Change
    file::Symbol
    line::Int
    expr::String
    occurrence::Int
    occurrences::Int
    primary_data::Vector{Float64}
    comparison_data::Vector{Float64}
end

# TODO: make this weak dep and/or move it to a separate package that lives in default environments
# but otoh, this mono-package has a 2-second precompile time and a 2ms load time and the versions
# of the two pacakges are tightly coupled so maybe not worth it?
# TODO: integrate with Revise (Revise triggers on ]test, but not on ]bench)
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

const WARNED = Ref(false)
const THRESHOLDS = Dict(45 => .005, 75 => .007, 120 => .008, 300 => .014)
function are_different(tags, data)
    length(tags) == length(data) || error("Length mismatch")
    n = Int(length(tags)/2)
    n in keys(THRESHOLDS) || ((WARNED[] || @warn("DEBUG MODE")); WARNED[] = true; return rand(Bool))
    threshold = THRESHOLDS[n]
    ut = unique(tags)
    length(ut) == 2 || error("Expected two tags")
    count(==(ut[1]), tags) == count(==(ut[2]), tags) == n || error("Expected equal counts")
    perm = sortperm(data) # A sorting dominated workload ?!?!?
    sum = 0
    err = 0
    for i in eachindex(data)
        sum += tags[perm[i]] == ut[1]
        delta = 2sum - i
        err += delta^2
    end
    @assert sum === n
    err < (threshold*n^3)*4+n && return false
    return true
end


# Callie

const FILTER = Ref{Union{Nothing, BitVector}}(nothing)
const STATIC_METADATA = Tuple{Symbol, Int, String}[]
const GROUP_ID = Ref(0)
const RUNTIME_METADATA = Int[]
const DATA = Float64[]
is_active() = FILTER[] === nothing || pop!(FILTER[])
macro group(expr)
    i = (GROUP_ID[] -= 1)
    quote
        let
            if is_active()
                push!(RUNTIME_METADATA, $i)
                $(esc(expr))
                push!(RUNTIME_METADATA, 0)
                nothing
            end
        end
    end
end
macro track(expr)
    # string(expr) causes O(n^2) macro expansion time for deeply nested `@task`s
    push!(STATIC_METADATA, (__source__.file, __source__.line, string(expr)))
    i = lastindex(STATIC_METADATA)
    quote
        let
            if is_active()
                x::Float64 = Float64($(esc(expr)))
                push!(RUNTIME_METADATA, $i)
                push!(DATA, x)
                nothing
            end
        end
    end
end

end
