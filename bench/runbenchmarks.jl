t = @elapsed using RegressionTests
@track t
using Chairmarks

# TODO: handle interruption well even with this naughty code
# try
#     while true
#         println("Infinite loop...")
#         sleep(.1)
#     end
# catch x
#     println("Caught exception: $x")
#     try
#         disable_sigint() do
#             while true
#                 println("Can't stop me now!")
#                 sleep(.01)
#             end
#         end
#     finally
#         println("???")
#     end
# end

# 463.5 => 306.8 => 52.3
for n in 1:50
    # @track begin
    #     res = @be n rand seconds=.01
    #     [minimum(res).time, Chairmarks.median(res).time, Chairmarks.mean(res).time]
    # end
    @group begin
        res = @be n rand seconds=.01
        @track minimum(res).time
        @track Chairmarks.median(res).time
        @track Chairmarks.mean(res).time
    end

    # This is the same as the previous 6 lines, but a bit more thourough and more concise:
    # @track @be n rand
end

for k in 1:100_000
    # 1e-10 false positivity * 4e6 tracked values =>
    # this should cause CI to fail at most 1/2500 times.
    @track k
    @track rand()
    @track randn()
    @track rand([1,7,2,9])
end
