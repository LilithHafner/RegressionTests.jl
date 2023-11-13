# RegressionTests

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://LilithHafner.github.io/RegressionTests.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://LilithHafner.github.io/RegressionTests.jl/dev/)
[![Build Status](https://github.com/LilithHafner/RegressionTests.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/LilithHafner/RegressionTests.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/LilithHafner/RegressionTests.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/LilithHafner/RegressionTests.jl)
[![PkgEval](https://JuliaCI.github.io/NanosoldierReports/pkgeval_badges/T/RegressionTests.svg)](https://JuliaCI.github.io/NanosoldierReports/pkgeval_badges/T/RegressionTests.html)
[![Aqua](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)


# Usage instructions by example (a tutorial)

Setup your package directory like this:

```
MyPackage
├── Project.toml
├── src
│   └── MyPackage.jl
├── test
│   └── runtests.jl
└── benchmarks
    └── runbenchmarks.jl
```

And put
```julia
import RegressionTests
RegressionTests.run(joinpath(dirname(@__DIR__), "bemchmarks", "runbenchmarks.jl"))
```

At the bottom of your `tests/runtests.jl` file. For the sake of consistency, this directory
structure is recommended.

Then in `benchmarks/runbenchmarks.jl` put

```julia
using RegressionTests, Chairmarks

@regression_test :auto @b rand(100)
@regression_test :auto @b rand(1000)
```

Then run `include("benchmarks/runbenchmarks.jl")` from the REPL. This will return
immediately and transform the file to

```julia
using RegressionTests, Chairmarks

@regression_test 0x4fcde3a9 @b rand(100)
@regression_test 0x0381af3e @b rand(1000)
```

Where the hex numbers are automatically generated unique identifiers for the tests so that
they can be tracked reliably across versions of the package. [The size of the random numbers
is determined automatically. It will match the size of the largest existing test identifier,
unless there are no existing tests, in which case it will be 32 bits.]

Then run your package tests with `]test`. This will run your existing tests, followed by a
new testset that runs all the regression tests. However, note that there are no tests in the
new testset. This is because the regression tests are not present on the previous version of
the repository, so they are not run. [Though they are run one time on the current version
to ensure that they correctly produce real numbers.]

Commit these changes and then run `]test` again. This time, the regression tests will be run
and should report two passed tests.

Now, change the code in the benchmark file to

```julia
using RegressionTests, Chairmarks

@regression_test 0x4fcde3a9 (@b rand(100)).time
@regression_test 0x0381af3e (@b rand(1010)).time
```

This time, when you run `]test`, the regression tests will fail. This is because the
second test now produces a higher number (higher is worse, by default).
