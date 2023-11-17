using Random, Plots, SpecialFunctions
using StatsBase: StatsBase

function Random.shuffle!(v::AbstractVector{Bool}) # https://github.com/JuliaLang/julia/pull/52133
    old_sum = sum(v)
    x = 2old_sum <= length(v)
    fuel = x ? old_sum : length(v) - old_sum
    fuel == 0 && return v
    v .= !x
    while 0 < fuel
        k = rand(eachindex(v))
        fuel -= v[k] != x
        v[k] = x
    end
    v
end

function sample(n::Integer, trials=1000; only_positive=false)
    x = Vector(vcat(falses(n), trues(n)))
    res = zeros(Int, trials)
    for i in 1:trials
        shuffle!(x)
        sum = 0
        err = 0
        for j in 1:2n
            sum += x[j]
            delta = 2sum - j
            delta < 0 && only_positive && continue
            err += delta^2
        end
        res[i] = only_positive ? round(Int,(err - n)/4) : Int((err - n)/4)
    end
    res
end

s(n) = sample(n, min(10_000_000, 1000_000_000 ÷ n)) / n^3

## False positives

X = []
Y = []
"""
With 100 samples, if k > .02, we have 5 9s of reliability (1e-5) on false positives,
and if k > .04, we have (extrapolated) 1e-10 reliability.
This function creates and plots empirical data to back this claim up.
"""
function plot_false_positives(;n=100, m=10_000_000, k=200, only_positive=false)
    data = sample(n, m; only_positive)
    x = sort!(data) / n^3
    y = 1 .- ((eachindex(x) .- 1) ./ length(x))

    inds = [1]
    xrange = last(x) - first(x)
    yrange = log(first(y)) - log(last(y))
    for i in eachindex(x, y)
        if log(y[last(inds)]) - log(y[i]) > yrange/k || x[i] - x[last(inds)] > xrange/k
            push!(inds, i)
        end
    end
    push!(X, x[inds])
    push!(Y, y[inds])
    plot!(x[inds], y[inds], yaxis=:log, yticks=10, xticks=10)
end

#=
```julia
x = s(100); plot(sort(x), 1 .- ((eachindex(x) .- 1) ./ length(x)), yaxis=:log, yticks=10)
```
=#


## False negatives (approach one)

"""
Normalize a polynomial so that it hits (-1,0) and (1,0) and
the integral from -1 to 1 of the polynomial squared is 1
"""
function normalize(params)
    a = evalpoly(-1, params)
    b = evalpoly(1, params)
    p1 = vcat(params[1] - (a+b)/2, params[2] - (b-a)/2, collect(params[3:end]))
    p2 = integrate_poly(square_poly(p1))
    int = evalpoly(1, p2) - evalpoly(-1, p2)
    p1 ./= sqrt(int)
    typeof(params)(p1)
end

"""
Square a polynomial represented as an array of coefficients
"""
square_poly(p::Vector) = [sum(p[j]*p[i-j+1] for j in max(firstindex(p), i-lastindex(p)+1):min(lastindex(p), i-firstindex(p)+1)) for i in firstindex(p):lastindex(p)+length(p)-1]
integrate_poly(p::Vector) = vcat(1729, [p[i]/i for i in eachindex(p)])
differentiate_poly(p) = [p[i]*i for i in 2:lastindex(p)]
add_root(p::Vector, root) = vcat(0, p) .- root*vcat(p, 0)

rand_poly_1(degree) = randn(degree+1)
function rand_poly_2(degree)
    p = randn(1) .* [1, 0, -1]
    for i in 3:degree
        p = add_root(p, randn())
    end
    p
end
function rand_poly_3(degree)
    p = randn(1) .* [1, 0, -1]
    for i in 3:degree
        p = add_root(p, 2rand()-1)
    end
    p
end
rand_poly(degree) = rand([rand_poly_1, rand_poly_2, rand_poly_3])(degree)
rand_poly() = rand_poly(rand(2:20))
randn_poly() = Tuple(normalize(rand_poly()))

function is_valid(p, k=.04)
    p2 = p .* sqrt(k)
    p3 = differentiate_poly(p2)
    maximum(abs.(evalpoly.(-1:.0001:1, (p3,)))) < 1
end


## Alias tables

using Random
using StatsBase: make_alias_table!

struct OneToInf <: AbstractVector{Int} end
Base.size(::OneToInf) = (typemax(Int),)
Base.getindex(::OneToInf, x::Int) = x
Base.iterate(::OneToInf, state=1) = (state, state+1)
Base.eltype(::Type{OneToInf}) = Int
Base.IteratorSize(::Type{OneToInf}) = Base.IsInfinite()
Base.show(io::IO, _::OneToInf) = print(io, "OneToInf()")
Base.:(==)(::OneToInf, ::OneToInf) = true

struct AliasTable{T, S} <: Random.Sampler{T} where {S <: AbstractVector{T}}
    accept::Vector{Float64}
    alias::Vector{Int}
    support::S
end

function AliasTable(probs::AbstractVector{<:Real}, support::AbstractVector=OneToInf())
    AliasTable!(Float64.(probs), support)
end
function AliasTable!(probs::AbstractVector{Float64}, support::AbstractVector=OneToInf())
    Base.has_offset_axes(probs, support) && throw(ArgumentError("offset arrays are not supported but got an array with index other than 1"))
    n = length(probs)
    n > 0 || throw(ArgumentError("The input probability vector is empty."))
    checkbounds(Bool, support, axes(probs, 1)) || throw(BoundsError("probabilities extend past support"))
    alias = similar(probs, Int)
    sum_probs = sum(probs)
    0 < sum_probs < Inf || throw(ArgumentError("sum(probs) = $sum_probs"))
    make_alias_table!(probs, sum_probs, probs, alias)
    alias .-= eachindex(alias) # TODO: upstream this performance improvement
    AliasTable{eltype(support), typeof(support)}(probs, alias, support)
end

# with an alias table that has a high proportion of guaranteed acceptance, this can be
# optimized to reduce the number of times u needs to be computed.
# StatsBase.make_alias_table! does not produce such a table.
function Random.rand(rng::AbstractRNG, s::AliasTable)
    i = rand(rng, eachindex(s.accept))
    u = rand(rng)
    # @inbounds s.support[u < s.accept[i] ? i : s.alias[i]]
    @inbounds s.support[(u >= s.accept[i]) * s.alias[i] + i] # TODO: upstream this performance improvement
end

Base.:(==)(a::AliasTable, b::AliasTable) =
    a.accept == b.accept && a.support == b.support && a.alias[a.accept .!= 1] == b.alias[b.accept .!= 1]

## end Alias tables

## False negatives (approach two)

struct Distribution
    μ::Vector{Float64}
    σ::Vector{Float64}
    weight::Vector{Float64}
    at::AliasTable{Int, OneToInf}
end
function Distribution(n)
    μ = randn(n)
    σ = randn(n).^2
    weight = rand(n)
    weight ./= sum(weight)
    Distribution(μ, σ, weight, AliasTable(weight))
end
function Base.rand(d::Distribution)
    i = rand(d.at)
    randn() * d.σ[i] + d.μ[i]
end

struct PDF <: Function
    dist::Distribution
end
struct CDF <: Function
    dist::Distribution
end
pdf(n) = PDF(Distribution(n))
pdf(x::CDF) = PDF(x.dist)
pdf(x::PDF) = x
pdf(x::Distribution) = PDF(x)
(pdf::PDF)(x) = sum(exp(-((x - μ) / σ).^2) / (σ * sqrt(π)) * w for (μ, σ, w) in zip(pdf.dist.μ, pdf.dist.σ, pdf.dist.weight))

cdf(n) = CDF(Distribution(n))
cdf(x::PDF) = CDF(x.dist)
cdf(x::CDF) = x
cdf(x::Distribution) = CDF(x)
(cdf::CDF)(x) = sum(erf((x - μ) ./ (σ * sqrt(2))) / 2 * w for (μ, σ, w) in zip(cdf.dist.μ, cdf.dist.σ, cdf.dist.weight))

get_k(f, g; kw...) = get_k(cdf(f), cdf(g); kw...)
function get_k(f::CDF, g::CDF; n=5_000)
    integral = 0.0
    xs = LinRange(-5, 5, n) # TODO: use better distribution
    f0, g0 = f(xs[1]), g(xs[1])
    for x in Iterators.drop(xs, 1)
        f1, g1 = f(x), g(x)

        dx = f1-f0
        b = g0-f0
        m = (g1-f1)-b
        integral += dx*(m^2/3+m*b+b^2)

        f0, g0 = f1, g1
    end
    integral
end

sample(d1::PDF, d2::PDF, n::Integer, arg...) = sample(d1.dist, d2.dist, n, arg...)
sample(d1::CDF, d2::CDF, n::Integer, trials=1000) = sample(d1.dist, d2.dist, n, trials)
function sample(d1::Distribution, d2::Distribution, n::Integer, trials=1000)
    res = zeros(Int, trials)
    data = Vector{Float64}(undef, 2n)
    for i in 1:trials
        for i in 1:n
            data[i] = reinterpret(Float64, reinterpret(UInt64, rand(d1)) | 0x01)
            data[i+n] = reinterpret(Float64, reinterpret(UInt64, rand(d2)) & ~UInt64(1))
        end
        sort!(data) # A sorting dominated workload ?!?!?
        sum = 0
        err = 0
        for j in 1:2n
            sum += Bool(reinterpret(UInt64, data[j]) & 0x01)
            delta = 2sum - j
            err += delta^2
        end
        res[i] = Int((err - n)/4)
    end
    res
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
    # Precision .9999999999 (estimated)
    # Worst case recall .95 for inputs that differ by at least k ≥ .05
    # Average trials on equal inputs 108
    # Maximin trials 600
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
# 90 / .007 5103
# 150 / .009 30374
# 300 / .013 378000

function cdf(data::Vector; rev=false)
    x = sort(data; rev)
    y = eachindex(x) ./ length(x)
    x, y
end
#n = 30; @time display(begin plot(cdf(sample(n, 1000_000)./n^3, rev=true), legend=false, title=n, yaxis=:log, xlims=(0.0,0.04), ylims=(1e-3, 1), yticks=15, xticks=15); [plot!(cdf(sample(cdfs..., n, 1000)./n^3)) for cdfs in cdfss]; plot!() end)

# 35 / .004 (1.5% false negative, 45% false positive)
# 40 / .004 (1.5% false negative, 38% false positive)

# 45 / .005 (1.5% false negative, 20% false positive) <-
# 75 / .007 (1% false negative, 5% false positive) <-
# 120 / .008 (0.5% false negative, 0.25% false positive) <-
# 300 / .014 (0.5% false negative, 1e-10 false positive) <-

# 30 / .010 (12% false negative, 13% false positive)
# 40 / .011 (10% false negative, 5% false positive)

function validate()
    # 80ms
    @time distributionss = [(Distribution(i), Distribution(j)) for i in 1:50 for j in 1:50];
    # 13s
    @time ks = [get_k(ds...) for ds in distributionss]

    total_evaluations_on_equal = Ref(0)
    # 7s
    trials = 300
    @time for ds in distributionss, d in ds
        f = () -> (total_evaluations_on_equal[] += 1; rand(d))
        any(differentiate(f, f) for _ in 1:trials) && error() # Should happen 1e-10*100*50^2 = 2.5e-5 of the time
    end
    average_evaluations_on_equal =
        total_evaluations_on_equal[] / sum(length, distributionss) / trials

    # 123s
    @time miss_rates = [begin
        f = () -> (rand(ds[1]))
        g = () -> (rand(ds[2]))
        misses = 0
        attempts = 0
        while attempts < 1000 || attempts < 20_000 && misses < 10
            attempts += 1
            differentiate(f, g) || (misses += 1)
        end
        misses/attempts
    end for ds in distributionss]

    ytick_pos = [1e-6; 10.0 .^ (-4:0)]
    ytick = vcat("0/20,000", ["1e$i" for i in -4:0])
    scatter(ks, (miss_rates .+ .1/100_000),
        yaxis=:log, xlabel="k", ylabel="miss rate", legend=false, markersize=2,
        yticks=(ytick_pos, ytick), xlims=(-.005, .155), xticks=0:.025:.15)
    plot_k = [.025, .105]
    scatter!([.05], [.05])
    plot!(plot_k, [20^(1-k/.025) for k in plot_k], color=:black, linestyle=:dash)
end