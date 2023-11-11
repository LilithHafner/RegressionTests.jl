module TablemarksCI

export parsefile, walktree, is_auto_benchmark_call, auto_benchmark_locations

using JuliaSyntax
include("juliasyntax.jl")

using Chairmarks

macro b_AUTO(ex...)
    isempty(ex) ? nothing : first(ex)
end

@b_AUTO 1+1
(@b_AUTO 17  ) , (@b_AUTO rand hash)
@b_AUTO(rand, hash)
@b_AUTO(rand)
@b_AUTO(rand,)
@b_AUTO(rand, )
@b_AUTO()
@b_AUTO ()
@b_AUTO
@b_AUTO(rand,   )
@b_AUTO(rand  )
@b_AUTO (rand)

function is_auto_benchmark_call(x::SyntaxNode)
    kind(x) === K"macrocall" || return false
    name = x.children[1]
    kind(name) === K"MacroName" || return false
    name.val === Symbol("@b_AUTO") || return false
    true
end

function transformation(x::SyntaxNode, rng=Random.default_rng())
    kind(x) === K"macrocall" || return nothing
    name = x.children[1]
    kind(name) === K"MacroName" || return nothing
    name.val === Symbol("@b_AUTO") || return nothing
    args = x.data.raw.args
    # println(typeof(x))
    global XXX = x
    endpos = x.data.position + x.data.raw.span - 1
    prefix, insertion_point = if head(x).flags === 0x0000
        lst = last(args)
        whitespace = kind(lst) === K"Whitespace" ? lst.span : 0
        " ", endpos + 1 - whitespace:endpos
    elseif head(x).flags === 0x0020
        kind(last(args)) === K")" || error("expected )")
        whitespace = kind(args[end-1]) === K"Whitespace"
        last_non_whitespace = args[end-1-whitespace]
        k = kind(last_non_whitespace)
        prefix = k === K"(" ? "" : k === K"," ? " " : ", "
        prefix, endpos - (whitespace ? args[end-1].span : 0) : endpos - 1
    else
        error("unknown flag")
    end
    span(name)=>"b", insertion_point=>(prefix * repr(rand(rng, UInt64)))
end

parsefile(T, file, arg...; kw...) = parseall(T, read(file, String), arg...; filename=basename(file), kw...)
parsefile(file, kw...) = parsefile(SyntaxNode, file, kw...)
span(x::SyntaxNode) = x.data.position:Int(x.data.position + x.data.raw.span - 1)

function auto_benchmark_locations(string::String; kw...)
    (span(x) for x in walktree(parseall(SyntaxNode, string; kw...)) if is_auto_benchmark_call(x))
end

function auto_benchmark_excerpts(string::String; kw...)
    (string[x] for x in auto_benchmark_locations(string; kw...))
end

function transform(string::String, replacements)
    rs = sort!(collect(replacements), by=x->x[1].start)::AbstractVector{<:Pair{<:UnitRange, <:AbstractString}}
    res = IOBuffer()
    print(res, string[1:first(first(rs)[1])-1])
    for ((s1, r2), (s2, _)) in zip(rs, Iterators.drop(rs, 1))
        print(res, r2)
        last(s1) < first(s2) || error("overlapping replacements, $(s1) and $(s2)")
        print(res, string[last(s1)+1:first(s2)-1])
    end
    print(res, rs[end][2])
    print(res, string[last(rs[end][1])+1:end])
    String(take!(res))
end

function transformations(str::String; rng, kw...)
    res = Vector{Pair{UnitRange{Int}, String}}()
    for x in walktree(parseall(SyntaxNode, str; kw...))
        # println(typeof(x))
        t = transformation(x, rng)
        t === nothing || push!(res, t...)
    end
    res
end

end