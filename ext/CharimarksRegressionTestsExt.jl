module CharimarksRegressionTestsExt

# TODO: move this to Chairmarks because it depends on
# Chairmarks's internals and RegressionTests's public API

using Chairmarks, RegressionTests

const tracked_properties = (:time, :allocs, :bytes, :gc_fraction, :compile_fraction, :recompile_fraction)

RegressionTests.trackable(s::Chairmarks.Sample) =
    NamedTuple(name => getproperty(s, name) for name in tracked_properties)

RegressionTests.trackable(b::Chairmarks.Benchmark) = NamedTuple(Symbol(symbol, " ", name) =>
    getproperty(sam, name) for (symbol, sam) in ((s, getproperty(Chairmarks, s)(b)) for s in
    (:minimum, :median, :mean)) for name in tracked_properties)

end
