# TODO: upstream this file into JuliaSyntax or use their API
struct WalkTree{T}
    x::T
end
walktree(x) = WalkTree(x)
has_children(x) = hasproperty(x, :children) && x.children !== nothing
get_children(x) = x.children
Base.IteratorSize(::Type{<:WalkTree}) = Base.SizeUnknown()
Base.iterate(x::WalkTree{T}) where T = (x.x, Tuple{T, Int}[(x.x, 0)])
function Base.iterate(x::WalkTree{T}, stack::Vector{Tuple{T, Int}}) where T
    current, index = stack[end]
    children = get_children(current)
    if index == lastindex(children)
        pop!(stack)
        isempty(stack) ? nothing : iterate(x, stack)
    else
        child = children[index+1]
        stack[end] = (current, index+1)
        has_children(child) && push!(stack, (child, 0))
        (child, stack)
    end
end
