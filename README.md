# RegressionTests

Regression tests without false positives

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://LilithHafner.github.io/RegressionTests.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://LilithHafner.github.io/RegressionTests.jl/dev/)
[![Build Status](https://github.com/LilithHafner/RegressionTests.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/LilithHafner/RegressionTests.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/LilithHafner/RegressionTests.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/LilithHafner/RegressionTests.jl)
[![PkgEval](https://JuliaCI.github.io/NanosoldierReports/pkgeval_badges/T/RegressionTests.svg)](https://JuliaCI.github.io/NanosoldierReports/pkgeval_badges/T/RegressionTests.html)
[![Aqua](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)


# Stability: Experimental

This package is buggy, examples are only partially tested, CI fails, and the API is under active development.

# Usage instructions by example (a tutorial)

Setup your package directory like this:

```
MyPackage
├── Project.toml
├── src
│   └── MyPackage.jl
├── test
│   └── runtests.jl
└── bench
    └── runbenchmarks.jl
```

Put this in your MyPackage.jl file:
```julia
module MyPackage
    function compute()
        return sum(rand(100))
    end
end
```
And commit your changes. This is our baseline.

Now, let's add regression tests. Put this in your `test/runtests.jl` file:
```julia
import RegressionTests
RegressionTests.test()
```

And put this in your `bench/runbenchmarks.jl` file:
```julia
using RegressionTests, Chairmarks, MyPackage

@track (@b MyPackage.compute() seconds=.01).time
```

The `@b` macro, from [`Chairmarks`](https://github.com/LilithHafner/Chairmarks.jl), will
benchmark the `compute` function, and the [`@track`] macro from `RegressionTests` will
track the result of that benchmark.

Then run your package tests with `]test`. The tests should pass and report that no
regressions were found.

Now, let's introduce a 10% regression. Change the `compute` function to this:
```julia
function compute()
    return sum(rand(110))
end
```

And rerun `]test`. The tests should fail and display the result of the regression test.

# `]bench`

Any time RegressionTests.jl is loaded, you can use `]bench` to run your benchmarks and
report the results which you can then revisit later by accessing `RegressionTests.RESULTS`.

To make the most use of this feature, you can add `using RegressionTests` to your startup.jl
file.

# Methodology

All the various ways of running benchmarks with this package funnel through a
`runbenchmarks` function which performs a randomized controlled trial comparing two
versions of a package. Each datapoint is a result of restarting Julia, loading a randomly
chosen version of the target package, and recording the tracked values.

The results are then compared in a value independent manner that makes no assumptions about
the actual values of the targets (other than that they are real numbers).

We make the following statistical claims for each tracked value `t`
- If the distributions of `t` is independent of the version being tested, then this will
  report a change with probability approximately `1e-10`.
- If the distributions of `t` on the two tested versions differ[^1] by at least `k ≥ .05`,
  then this will report a change with probability `≤ 0.95`[^2].
- All reported changes are tagged as either increases, decreases, or both.
- If all percentiles of `t` are on the primary version are greater than or equal to their
  corresponding values on the comparison version, then `t` will be incorrectly reported as a
  decrease with probability `≤ 1e-5`. (and vice versa)
- If there is an increase with significance[^1] `k ≥ .05`, then that increase will be reported
  with probability `≥ 0.95`.

[^1]: Significance is measured by the integral from 0 to 1 of `(cdf(g)(invcdf(f)(x)) - x)^2`.
This can be thought of as the squared area of deviation from x=y in the cdf/cdf plot. When
referring to increases or degreases, we only count area on one side of the x=y line. The
gist of this is that we report a positive result for anything that can be efficiently
detected with low false positivity rates.

[^2]: More generally, for any `k > .025`, `recall` loss is, according to empirical
estimation, at most `max(1e-4, 20^(1-k/.025))`. So, for example, a regression with `k = .1`,
will escape detection at most 1 out of 8000 times.

Note: the numbers in these statistical claims are based on empirical data. They likely
accurate, but we're still looking for proofs and closed forms.

# Supported platforms and versions

Julia version | Linux | MacOS | Windows | Other
--------------|-----|------|------|-----
≤0.7          | ❌  | ❌  | ❌  | ❌
1.0           | ⚠️+  | ⚠️+ | ⚠️+ | ⚠️
[1.1, 1.5]    | ⚠️   | ⚠️  | ⚠️  | ⚠️
1.6           | ✅+ | ✅+ | ⚠️+ | ?
[1.7, stable) | ✅  | ✅  | ⚠️  | ?
stable        | ✅+ | ✅+ | ⚠️+ | ?
nightly       | ?+ | ?+ | ?+ | ?

❌ Not supported\
⚠️ Not functional, but `RegressionTests.test(skip_unsupported_platforms=true)` works\
✅ Supported\
? Unknown and subject to change at any time\
\+ Tested in CI
