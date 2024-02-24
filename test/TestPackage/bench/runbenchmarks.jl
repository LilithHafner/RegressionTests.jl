using RegressionTests
using Chairmarks

t = @elapsed using TestPackage
@track t # in case the @track doesn't run TODO: add `required=true` or `skip=false` option

for len in [1, 10, 100]
    @group begin
        x = rand(len)
        @track @elapsed my_sum(x)
        @track @elapsed for _ in 1:100 my_sum(x) end
        @track @elapsed for _ in 1:100 my_sum(x) end

        @track @elapsed my_prod(x)
        @track @elapsed for _ in 1:100 my_prod(x) end
        @track @elapsed for _ in 1:100 my_prod(x) end

        @track @b my_sum(x)
        @track @b my_prod(x)
        @track @be my_sum(x)
        @track @be my_prod(x)
    end
end
