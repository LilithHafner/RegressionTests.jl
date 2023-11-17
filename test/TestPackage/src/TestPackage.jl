module TestPackage

export my_sum, my_prod

my_sum(x) = sum(Float64.(x))
my_prod(x) = prod(x)

end
