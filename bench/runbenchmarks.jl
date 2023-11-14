println("Hi!")
println(pwd())
import Pkg
println(Pkg.status())

for n in [1, 10, 100]
    x = @be n rand
    @track minimum(be).times
    @track median(be).times
    @track mean(be).times
end
