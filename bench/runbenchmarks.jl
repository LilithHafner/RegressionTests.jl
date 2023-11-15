using RegressionTests
using Chairmarks

# 463.5 => 306.8 => 52.3
for n in 1:50
    @track begin
        res = @be n rand seconds=.01
        [minimum(res).time, Chairmarks.median(res).time, Chairmarks.mean(res).time]
    end
    # TODO: use "group" syntax
    # @group begin
    #     res = @be n rand
    #     @track minimum(res).time
    #     @track Chairmarks.median(res).time
    #     @track Chairmarks.mean(res).time
    # end
end

# for k in 1:1_000_00#0
#     @track k
# end