module TablemarksCI

export @b_AUTO

using Random
using JuliaSyntax
include("juliasyntax.jl")
include("b_auto.jl")

"""
    changed(f, g, tol, precision=.99999, recall=.99)

Uses statistical analysis to see if `f()::Real` and `g()::Real` produce the same result.

Estimates the average value of `f()` and `g()` over multiple trials and returns `:increase`
if `f̄ < ḡ`, `:decrease` if `f̄ > ḡ`, and `:unchanged` if `abs(ḡ - f̄) < tol`.

Will only report `:increase` or `:decrease` if the result is statistically significant at
the p value of `1 - precision`. Will only report `:unchanged` if the result is statistically
significant at the p value of `1 - recall`.
"""
function changed(f, g, tol, precision=.99999, recall=.99)
    tol > 0 || throw(ArgumentError("tol must be positive"))
    0 < precision < 1 || throw(ArgumentError("precision must be between 0 and 1"))
    0 < recall < 1 || throw(ArgumentError("recall must be between 0 and 1"))

    fs = [f() for _ in 1:30]
    gs = [g() for _ in 1:30]

    f̄ = mean(fs)
    ḡ = mean(gs)
end

end