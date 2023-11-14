# println("Hi!")
# println(pwd())
import Pkg
# println(Pkg.status())
using TablemarksCI
using Chairmarks
@b 1+1
@be 1+1

for n in 1:200
    res = @be n rand
    @track minimum(res).time
    @track Chairmarks.median(res).time
    @track Chairmarks.mean(res).time
end

for k in 1:1_000_00#0
    @track k
end