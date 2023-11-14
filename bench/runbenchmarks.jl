# println("Hi!")
# println(pwd())
import Pkg
# println(Pkg.status())
using TablemarksCI
using Chairmarks
@b 1+1
@be 1+1
# 463.5
for n in 1:20
    @track begin
        res = @be n rand
        [minimum(res).time, Chairmarks.median(res).time, Chairmarks.mean(res).time]
    end
end

for k in 1:1_000_00#0
    @track k
end