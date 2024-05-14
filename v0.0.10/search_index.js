var documenterSearchIndex = {"docs":
[{"location":"","page":"Home","title":"Home","text":"CurrentModule = RegressionTests","category":"page"},{"location":"#RegressionTests","page":"Home","title":"RegressionTests","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Documentation for RegressionTests.","category":"page"},{"location":"","page":"Home","title":"Home","text":"","category":"page"},{"location":"","page":"Home","title":"Home","text":"Modules = [RegressionTests]","category":"page"},{"location":"#RegressionTests.differentiate-Tuple{Any, Any}","page":"Home","title":"RegressionTests.differentiate","text":"differentiate(f, g)\n\nDetermine if f() and g() have different distributions.\n\nReturns false if f and g have the same distribution and usually returns true if they have different distributions.\n\nProperties\n\nIf f and g have the same distribution, the probability of a false positive is 1e-10.\nIf f and g have distributions that differ* by at least .05, then the probability of   a false negative is .05.\nIf f and g have the same distribution, f and g will each be called 53 times, on   average\nf and g will each be called at most 300 times.\n\nThe difference between distributions is quantified as the integral from 0 to 1 of (cdf(g)(invcdf(f)(x)) - x)^2 where cdf and invcdf are higher order functions that compute the cumulative distribution function and inverse cumulative distribution function, respectively.\n\nMore generally, for any k > .025, recall loss is according to empirical estimation, at most max(1e-4, 20^(1-k/.025)). So, for example, a regression with k = .1, will be escape detection at most 1 out of 8000 times.\n\n\n\n\n\n","category":"method"},{"location":"#RegressionTests.runbenchmarks-Tuple","page":"Home","title":"RegressionTests.runbenchmarks","text":"runbenchmarks()\n\nWhen called in test/runtests.jl while pwd() points to test, this function runs the benchmarks in bench/runbenchmarks.jl.\n\nThere are some keyword arguments, but they are not public.\n\n\n\n\n\n","category":"method"},{"location":"#RegressionTests.test-Tuple{}","page":"Home","title":"RegressionTests.test","text":"test(skip_unsupported_platforms=false)\n\nWhen called in testing, runs regression tests, reports all changes, and throws if there are regressions.\n\nSet skip_unsupported_platforms to true to skip the test (quietly pass) on platforms that are not supported.\n\n\n\n\n\n","category":"method"},{"location":"#RegressionTests.trackable-Tuple{Real}","page":"Home","title":"RegressionTests.trackable","text":"trackable(x) -> Union{Float64, NamedTuple{<:Any, NTuple{<:Any, Float64}}}\n\nConvert an object into a Float64 or NamedTuple of Float64s for tracking. Called automatically by @track expr on the result of expr.\n\nDefine new methods for this function to track non-Real types.\n\n\n\n\n\n","category":"method"},{"location":"#RegressionTests.@group-Tuple{Any}","page":"Home","title":"RegressionTests.@group","text":"@group expr\n\nGroup multiple tracked values together with setup code so that they may all be omitted if the first several trials do not indicate a plausible change in any of the grouped tracked values.\n\nExample\n\n@group begin\n    x = rand(100)\n    sm = sum(x)\n    @track abs(sm - foldl(+, x))\n    @track sm / mean(x)\nend\n\n\n\n\n\n","category":"macro"},{"location":"#RegressionTests.@track-Tuple{Any}","page":"Home","title":"RegressionTests.@track","text":"@track expr\n\nTrack the return value of expr for regressions. expr must evaluate to a number that can be converted to a Float64.\n\nIf the first several trials do not indicate a plausible change in the tracked value then subsequent trials may skip evaluating expr. Do not put code in an @track expression that has side effects needed later on.\n\nShould be used in or included by a runbenchmarks.jl file.\n\nExamples\n\n@track begin\n    x = rand(100)\n    abs(sum(x) - foldl(+, x))\nend\n\ny = rand(100)\n@track abs(sum(y) - foldl(+, y))\n@track sum(y) / mean(y)\n\n\n\n\n\n","category":"macro"},{"location":"#Using-a-development-version-of-this-package","page":"Home","title":"Using a development version of this package","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"To run regression tests on MyPackage using a development version of RegressionTests, run","category":"page"},{"location":"","page":"Home","title":"Home","text":"]activate MyPackage\n]dev RegressionTests","category":"page"},{"location":"","page":"Home","title":"Home","text":"Note that this will add RegressionTests as a direct primary dependency of your package. This is currently required.","category":"page"}]
}