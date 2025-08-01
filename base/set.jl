# This file is a part of Julia. License is MIT: https://julialang.org/license

"""
    Set{T} <: AbstractSet{T}

`Set`s are mutable containers that provide fast membership testing.

`Set`s have efficient implementations of set operations such as `in`, `union` and `intersect`.
Elements in a `Set` are unique, as determined by the elements' definition of `isequal`.
The order of elements in a `Set` is an implementation detail and cannot be relied on.

See also: [`AbstractSet`](@ref), [`BitSet`](@ref), [`Dict`](@ref),
[`push!`](@ref), [`empty!`](@ref), [`union!`](@ref), [`in`](@ref), [`isequal`](@ref)

# Examples
```jldoctest; filter = r"^  '.'"ma
julia> s = Set("aaBca")
Set{Char} with 3 elements:
  'a'
  'c'
  'B'

julia> push!(s, 'b')
Set{Char} with 4 elements:
  'a'
  'b'
  'B'
  'c'

julia> s = Set([NaN, 0.0, 1.0, 2.0]);

julia> -0.0 in s # isequal(0.0, -0.0) is false
false

julia> NaN in s # isequal(NaN, NaN) is true
true
```
"""
struct Set{T} <: AbstractSet{T}
    dict::Dict{T,Nothing}

    global _Set(dict::Dict{T,Nothing}) where {T} = new{T}(dict)
end

Set{T}() where {T} = _Set(Dict{T,Nothing}())
Set{T}(s::Set{T}) where {T} = _Set(Dict{T,Nothing}(s.dict))
Set{T}(itr) where {T} = union!(Set{T}(), itr)
Set() = Set{Any}()

function Set{T}(s::KeySet{T, <:Dict{T}}) where {T}
    d = s.dict
    slots = copy(d.slots)
    keys = copy(d.keys)
    vals = similar(d.vals, Nothing)
    _Set(Dict{T,Nothing}(slots, keys, vals, d.ndel, d.count, d.age, d.idxfloor, d.maxprobe))
end

Set(itr) = _Set(itr, IteratorEltype(itr))
_Set(itr, ::HasEltype) = Set{eltype(itr)}(itr)

function _Set(itr, ::EltypeUnknown)
    T = @default_eltype(itr)
    (isconcretetype(T) || T === Union{}) || return grow_to!(Set{T}(), itr)
    return Set{T}(itr)
end

empty(s::AbstractSet{T}, ::Type{U}=T) where {T,U} = Set{U}()

# return an empty set with eltype T, which is mutable (can be grown)
# by default, a Set is returned
emptymutable(s::AbstractSet{T}, ::Type{U}=T) where {T,U} = Set{U}()

_similar_for(c::AbstractSet, ::Type{T}, itr, isz, len) where {T} = empty(c, T)

function show(io::IO, s::Set)
    if isempty(s)
        if get(io, :typeinfo, Any) == typeof(s)
            print(io, "Set()")
        else
            show(io, typeof(s))
            print(io, "()")
        end
    else
        print(io, "Set(")
        show_vector(io, s)
        print(io, ')')
    end
end

isempty(s::Set) = isempty(s.dict)
length(s::Set)  = length(s.dict)
in(x, s::Set) = haskey(s.dict, x)

"""
    in!(x, s::AbstractSet)::Bool

If `x` is in `s`, return `true`. If not, push `x` into `s` and return `false`.
This is equivalent to `in(x, s) ? true : (push!(s, x); false)`, but may have a
more efficient implementation.

See also: [`in`](@ref), [`push!`](@ref), [`Set`](@ref)

!!! compat "Julia 1.11"
    This function requires at least 1.11.

# Examples
```jldoctest; filter = r"^\\s+\\d\$"m
julia> s = Set{Any}([1, 2, 3]); in!(4, s)
false

julia> length(s)
4

julia> in!(0x04, s)
true

julia> s
Set{Any} with 4 elements:
  4
  2
  3
  1
```
"""
function in!(x, s::AbstractSet)
    x ∈ s ? true : (push!(s, x); false)
end

function in!(x, s::Set)
    xT = convert(eltype(s), x)
    idx, sh = ht_keyindex2_shorthash!(s.dict, xT)
    idx > 0 && return true
    _setindex!(s.dict, nothing, xT, -idx, sh)
    return false
end

push!(s::Set, x) = (s.dict[x] = nothing; s)

function pop!(s::Set, x, default)
    dict = s.dict
    index = ht_keyindex(dict, x)
    if index > 0
        @inbounds key = dict.keys[index]
        _delete!(dict, index)
        return key
    else
        return default
    end
end

function pop!(s::Set, x)
    index = ht_keyindex(s.dict, x)
    index < 1 && throw(KeyError(x))
    result = @inbounds s.dict.keys[index]
    _delete!(s.dict, index)
    result
end

function pop!(s::Set)
    isempty(s) && throw(ArgumentError("set must be non-empty"))
    return pop!(s.dict)[1]
end

delete!(s::Set, x) = (delete!(s.dict, x); s)

copy(s::Set) = copymutable(s)

copymutable(s::Set{T}) where {T} = Set{T}(s)
# Set is the default mutable fall-back
copymutable(s::AbstractSet{T}) where {T} = Set{T}(s)

sizehint!(s::Set, newsz::Integer; shrink::Bool=true) = (sizehint!(s.dict, newsz; shrink); s)
empty!(s::Set) = (empty!(s.dict); s)
rehash!(s::Set) = (rehash!(s.dict); s)

iterate(s::Set, i...)       = iterate(KeySet(s.dict), i...)

@propagate_inbounds Iterators.only(s::Set) = Iterators._only(s, first)

# In case the size(s) is smaller than size(t) its more efficient to iterate through
# elements of s instead and only delete the ones also contained in t.
# The threshold for this decision boils down to a tradeoff between
# size(s) * cost(in() + delete!()) ≶ size(t) * cost(delete!())
# Empirical observations on Ints point towards a threshold of 0.8.
# To be on the safe side (e.g. cost(in) >>> cost(delete!) ) a
# conservative threshold of 0.5 was chosen.
function setdiff!(s::Set, t::Set)
    if 2 * length(s) < length(t)
        for x in s
            x in t && delete!(s, x)
        end
    else
        for x in t
            delete!(s, x)
        end
    end
    return s
end

"""
    unique(itr)

Return an array containing only the unique elements of collection `itr`,
as determined by [`isequal`](@ref) and [`hash`](@ref), in the order that the first of each
set of equivalent elements originally appears. The element type of the
input is preserved.

See also: [`unique!`](@ref), [`allunique`](@ref), [`allequal`](@ref).

# Examples
```jldoctest
julia> unique([1, 2, 6, 2])
3-element Vector{Int64}:
 1
 2
 6

julia> unique(Real[1, 1.0, 2])
2-element Vector{Real}:
 1
 2
```
"""
function unique(itr)
    if isa(IteratorEltype(itr), HasEltype)
        T = eltype(itr)
        out = Vector{T}()
        seen = Set{T}()
        for x in itr
            !in!(x, seen) && push!(out, x)
        end
        return out
    end
    T = @default_eltype(itr)
    y = iterate(itr)
    y === nothing && return T[]
    x, i = y
    S = typeof(x)
    R = isconcretetype(T) ? T : S
    return _unique_from(itr, R[x], Set{R}((x,)), i)
end

_unique_from(itr, out, seen, i) = unique_from(itr, out, seen, i)
@inline function unique_from(itr, out::Vector{T}, seen, i) where T
    while true
        y = iterate(itr, i)
        y === nothing && break
        x, i = y
        S = typeof(x)
        if !(S === T || S <: T)
            R = promote_typejoin(S, T)
            seenR = convert(Set{R}, seen)
            outR = convert(Vector{R}, out)
            !in!(x, seenR) && push!(outR, x)
            return _unique_from(itr, outR, seenR, i)
        end
        !in!(x, seen) && push!(out, x)
    end
    return out
end

unique(r::AbstractRange) = allunique(r) ? r : oftype(r, r[begin]:r[begin])

"""
    unique(f, itr)

Return an array containing one value from `itr` for each unique value produced by `f`
applied to elements of `itr`.

# Examples
```jldoctest
julia> unique(x -> x^2, [1, -1, 3, -3, 4])
3-element Vector{Int64}:
 1
 3
 4
```
This functionality can also be used to extract the *indices* of the first
occurrences of unique elements in an array:
```jldoctest
julia> a = [3.1, 4.2, 5.3, 3.1, 3.1, 3.1, 4.2, 1.7];

julia> i = unique(i -> a[i], eachindex(a))
4-element Vector{Int64}:
 1
 2
 3
 8

julia> a[i]
4-element Vector{Float64}:
 3.1
 4.2
 5.3
 1.7

julia> a[i] == unique(a)
true
```
"""
function unique(f, C; seen::Union{Nothing,Set}=nothing)
    out = Vector{eltype(C)}()
    if seen !== nothing
        for x in C
            !in!(f(x), seen) && push!(out, x)
        end
        return out
    end

    s = iterate(C)
    if s === nothing
        return out
    end
    (x, i) = s
    y = f(x)
    seen = Set{typeof(y)}()
    push!(seen, y)
    push!(out, x)

    return _unique!(f, out, C, seen, i)
end

function _unique!(f, out::AbstractVector, C, seen::Set, i)
    s = iterate(C, i)
    while s !== nothing
        (x, i) = s
        y = f(x)
        if y ∉ seen
            push!(out, x)
            if y isa eltype(seen)
                push!(seen, y)
            else
                seen2 = convert(Set{promote_typejoin(eltype(seen), typeof(y))}, seen)
                push!(seen2, y)
                return _unique!(f, out, C, seen2, i)
            end
        end
        s = iterate(C, i)
    end

    return out
end

"""
    unique!(f, A::AbstractVector)

Selects one value from `A` for each unique value produced by `f` applied to
elements of `A`, then return the modified A.

!!! compat "Julia 1.1"
    This method is available as of Julia 1.1.

# Examples
```jldoctest
julia> unique!(x -> x^2, [1, -1, 3, -3, 4])
3-element Vector{Int64}:
 1
 3
 4

julia> unique!(n -> n%3, [5, 1, 8, 9, 3, 4, 10, 7, 2, 6])
3-element Vector{Int64}:
 5
 1
 9

julia> unique!(iseven, [2, 3, 5, 7, 9])
2-element Vector{Int64}:
 2
 3
```
"""
function unique!(f, A::AbstractVector; seen::Union{Nothing,Set}=nothing)
    if length(A) <= 1
        return A
    end

    i = firstindex(A)::Int
    x = @inbounds A[i]
    y = f(x)
    if seen === nothing
        seen = Set{typeof(y)}()
    end
    push!(seen, y)
    return _unique!(f, A, seen, i, i+1)
end

function _unique!(f, A::AbstractVector, seen::Set, current::Integer, i::Integer)
    while i <= lastindex(A)
        x = @inbounds A[i]
        y = f(x)
        if y ∉ seen
            current += 1
            @inbounds A[current] = x
            if y isa eltype(seen)
                push!(seen, y)
            else
                seen2 = convert(Set{promote_typejoin(eltype(seen), typeof(y))}, seen)
                push!(seen2, y)
                return _unique!(f, A, seen2, current, i+1)
            end
        end
        i += 1
    end
    return resize!(A, current - firstindex(A)::Int + 1)::typeof(A)
end


# If A is not grouped, then we will need to keep track of all of the elements that we have
# seen so far.
_unique!(A::AbstractVector) = unique!(identity, A::AbstractVector)

# If A is grouped, so that each unique element is in a contiguous group, then we only
# need to keep track of one element at a time. We replace the elements of A with the
# unique elements that we see in the order that we see them. Once we have iterated
# through A, we resize A based on the number of unique elements that we see.
function _groupedunique!(A::AbstractVector)
    isempty(A) && return A
    idxs = eachindex(A)
    y = first(A)
    # We always keep the first element
    T = NTuple{2,Any} # just to eliminate `iterate(idxs)::Nothing` candidate
    it = iterate(idxs, (iterate(idxs)::T)[2])
    count = 1
    for x in Iterators.drop(A, 1)
        if !isequal(x, y)
            it = it::T
            y = A[it[1]] = x
            count += 1
            it = iterate(idxs, it[2])
        end
    end
    resize!(A, count)::typeof(A)
end

"""
    unique!(A::AbstractVector)

Remove duplicate items as determined by [`isequal`](@ref) and [`hash`](@ref), then return the modified `A`.
`unique!` will return the elements of `A` in the order that they occur. If you do not care
about the order of the returned data, then calling `(sort!(A); unique!(A))` will be much
more efficient as long as the elements of `A` can be sorted.

# Examples
```jldoctest
julia> unique!([1, 1, 1])
1-element Vector{Int64}:
 1

julia> A = [7, 3, 2, 3, 7, 5];

julia> unique!(A)
4-element Vector{Int64}:
 7
 3
 2
 5

julia> B = [7, 6, 42, 6, 7, 42];

julia> sort!(B);  # unique! is able to process sorted data much more efficiently.

julia> unique!(B)
3-element Vector{Int64}:
  6
  7
 42
```
"""
function unique!(itr)
    if isa(itr, AbstractVector)
        if OrderStyle(eltype(itr)) === Ordered()
            (issorted(itr) || issorted(itr, rev=true)) && return _groupedunique!(itr)
        end
    end
    isempty(itr) && return itr
    return _unique!(itr)
end

"""
    allunique(itr)::Bool
    allunique(f, itr)::Bool

Return `true` if all values from `itr` are distinct when compared with [`isequal`](@ref).
Or if all of `[f(x) for x in itr]` are distinct, for the second method.

Note that `allunique(f, itr)` may call `f` fewer than `length(itr)` times.
The precise number of calls is regarded as an implementation detail.

`allunique` may use a specialized implementation when the input is sorted.

See also: [`unique`](@ref), [`issorted`](@ref), [`allequal`](@ref).

!!! compat "Julia 1.11"
    The method `allunique(f, itr)` requires at least Julia 1.11.

# Examples
```jldoctest
julia> allunique([1, 2, 3])
true

julia> allunique([1, 2, 1, 2])
false

julia> allunique(Real[1, 1.0, 2])
false

julia> allunique([NaN, 2.0, NaN, 4.0])
false

julia> allunique(abs, [1, -1, 2])
false
```
"""
function allunique(C)
    if haslength(C)
        length(C) < 2 && return true
        length(C) < 32 && return _indexed_allunique(collect(C))
    end
    return _hashed_allunique(C)
end

allunique(f, xs) = allunique(Generator(f, xs))

function _hashed_allunique(C)
    seen = Set{@default_eltype(C)}()
    x = iterate(C)
    if haslength(C) && length(C) > 1000
        for i in OneTo(1000)
            v, s = something(x)
            in!(v, seen) && return false
            x = iterate(C, s)
        end
        sizehint!(seen, length(C))
    end
    while x !== nothing
        v, s = x
        in!(v, seen) && return false
        x = iterate(C, s)
    end
    return true
end

allunique(::Union{AbstractSet,AbstractDict}) = true

allunique(r::AbstractRange) = !iszero(step(r)) || length(r) <= 1

function allunique(A::StridedArray)
    if length(A) < 32
        _indexed_allunique(A)
    elseif OrderStyle(eltype(A)) === Ordered()
        a1, rest1 = Iterators.peel(A)::Tuple{Any,Any}
        a2, rest = Iterators.peel(rest1)::Tuple{Any,Any}
        if !isequal(a1, a2)
            compare = isless(a1, a2) ? isless : (a,b) -> isless(b,a)
            for a in rest
                if compare(a2, a)
                    a2 = a
                elseif isequal(a2, a)
                    return false
                else
                    return _hashed_allunique(A)
                end
            end
        else # isequal(a1, a2)
            return false
        end
        return true
    else
        _hashed_allunique(A)
    end
end

function _indexed_allunique(A)
    length(A) < 2 && return true
    iter = eachindex(A)
    I = iterate(iter)
    while I !== nothing
        i, s = I
        a = A[i]
        for j in Iterators.rest(iter, s)
            isequal(a, @inbounds A[j]) && return false
        end
        I = iterate(iter, s)
    end
    return true
end

function allunique(t::Tuple)
    length(t) < 32 || return _hashed_allunique(t)
    a = afoldl(true, tail(t)...) do b, x
        b & !isequal(first(t), x)
    end
    return a && allunique(tail(t))
end
allunique(t::Tuple{}) = true

function allunique(f::F, t::Tuple) where {F}
    length(t) < 2 && return true
    length(t) < 32 || return _hashed_allunique(Generator(f, t))
    return allunique(map(f, t))
end

"""
    allequal(itr)::Bool
    allequal(f, itr)::Bool

Return `true` if all values from `itr` are equal when compared with [`isequal`](@ref).
Or if all of `[f(x) for x in itr]` are equal, for the second method.

Note that `allequal(f, itr)` may call `f` fewer than `length(itr)` times.
The precise number of calls is regarded as an implementation detail.

See also: [`unique`](@ref), [`allunique`](@ref).

!!! compat "Julia 1.8"
    The `allequal` function requires at least Julia 1.8.

!!! compat "Julia 1.11"
    The method `allequal(f, itr)` requires at least Julia 1.11.

# Examples
```jldoctest
julia> allequal([])
true

julia> allequal([1])
true

julia> allequal([1, 1])
true

julia> allequal([1, 2])
false

julia> allequal(Dict(:a => 1, :b => 1))
false

julia> allequal(abs2, [1, -1])
true
```
"""
function allequal(itr)
    if haslength(itr)
        length(itr) <= 1 && return true
    end
    pl = Iterators.peel(itr)
    isnothing(pl) && return true
    a, rest = pl
    return all(isequal(a), rest)
end

allequal(c::Union{AbstractSet,AbstractDict}) = length(c) <= 1

allequal(r::AbstractRange) = iszero(step(r)) || length(r) <= 1

allequal(f, xs) = allequal(Generator(f, xs))

function allequal(f, xs::Tuple)
    length(xs) <= 1 && return true
    f1 = f(xs[1])
    for x in tail(xs)
        isequal(f1, f(x)) || return false
    end
    return true
end

filter!(f, s::Set) = unsafe_filter!(f, s)

const hashs_seed = UInt === UInt64 ? 0x852ada37cfe8e0ce : 0xcfe8e0ce
function hash(s::AbstractSet, h::UInt)
    hv = hashs_seed
    for x in s
        hv ⊻= hash(x)
    end
    hash(hv, h)
end

convert(::Type{T}, s::T) where {T<:AbstractSet} = s
convert(::Type{T}, s::AbstractSet) where {T<:AbstractSet} = T(s)::T


## replace/replace! ##

function check_count(count::Integer)
    count < 0 && throw(DomainError(count, "`count` must not be negative (got $count)"))
    return min(count, typemax(Int)) % Int
end

# TODO: use copy!, which is currently unavailable from here since it is defined in Future
_copy_oftype(x, ::Type{T}) where {T} = copyto!(similar(x, T), x)
# TODO: use similar() once deprecation is removed and it preserves keys
_copy_oftype(x::AbstractDict, ::Type{Pair{K,V}}) where {K,V} = merge!(empty(x, K, V), x)
_copy_oftype(x::AbstractSet, ::Type{T}) where {T} = union!(empty(x, T), x)

_copy_oftype(x::AbstractArray{T}, ::Type{T}) where {T} = copy(x)
_copy_oftype(x::AbstractDict{K,V}, ::Type{Pair{K,V}}) where {K,V} = copy(x)
_copy_oftype(x::AbstractSet{T}, ::Type{T}) where {T} = copy(x)

_similar_or_copy(x::Any) = similar(x)
_similar_or_copy(x::Any, ::Type{T}) where {T} = similar(x, T)
# Make a copy on construction since it is faster than inserting elements separately
_similar_or_copy(x::Union{AbstractDict,AbstractSet}) = copy(x)
_similar_or_copy(x::Union{AbstractDict,AbstractSet}, ::Type{T}) where {T} = _copy_oftype(x, T)

# to make replace/replace! work for a new container type Cont, only
# _replace!(new::Callable, res::Cont, A::Cont, count::Int)
# has to be implemented

"""
    replace!(A, old_new::Pair...; [count::Integer])

For each pair `old=>new` in `old_new`, replace all occurrences
of `old` in collection `A` by `new`.
Equality is determined using [`isequal`](@ref).
If `count` is specified, then replace at most `count` occurrences in total.
See also [`replace`](@ref replace(A, old_new::Pair...)).

# Examples
```jldoctest; filter = r"^\\s+\\d\$"m
julia> replace!([1, 2, 1, 3], 1=>0, 2=>4, count=2)
4-element Vector{Int64}:
 0
 4
 1
 3

julia> replace!(Set([1, 2, 3]), 1=>0)
Set{Int64} with 3 elements:
  0
  2
  3
```
"""
replace!(A, old_new::Pair...; count::Integer=typemax(Int)) =
    replace_pairs!(A, A, check_count(count), old_new)

function replace_pairs!(res, A, count::Int, old_new::Tuple{Vararg{Pair}})
    @inline function new(x)
        for o_n in old_new
            isequal(first(o_n), x) && return last(o_n)
        end
        return x # no replace
    end
    _replace!(new, res, A, count)
end

"""
    replace!(new::Union{Function, Type}, A; [count::Integer])

Replace each element `x` in collection `A` by `new(x)`.
If `count` is specified, then replace at most `count` values in total
(replacements being defined as `new(x) !== x`).

# Examples
```jldoctest; filter = r"^\\s+\\d+(\\s+=>\\s+\\d)?\$"m
julia> replace!(x -> isodd(x) ? 2x : x, [1, 2, 3, 4])
4-element Vector{Int64}:
 2
 2
 6
 4

julia> replace!(Dict(1=>2, 3=>4)) do kv
           first(kv) < 3 ? first(kv)=>3 : kv
       end
Dict{Int64, Int64} with 2 entries:
  3 => 4
  1 => 3

julia> replace!(x->2x, Set([3, 6]))
Set{Int64} with 2 elements:
  6
  12
```
"""
replace!(new::Callable, A; count::Integer=typemax(Int)) =
    _replace!(new, A, A, check_count(count))

"""
    replace(A, old_new::Pair...; [count::Integer])

Return a copy of collection `A` where, for each pair `old=>new` in `old_new`,
all occurrences of `old` are replaced by `new`.
Equality is determined using [`isequal`](@ref).
If `count` is specified, then replace at most `count` occurrences in total.

The element type of the result is chosen using promotion (see [`promote_type`](@ref))
based on the element type of `A` and on the types of the `new` values in pairs.
If `count` is omitted and the element type of `A` is a `Union`, the element type
of the result will not include singleton types which are replaced with values of
a different type: for example, `Union{T,Missing}` will become `T` if `missing` is
replaced.

See also [`replace!`](@ref), [`splice!`](@ref), [`delete!`](@ref), [`insert!`](@ref).

!!! compat "Julia 1.7"
    Version 1.7 is required to replace elements of a `Tuple`.

# Examples
```jldoctest
julia> replace([1, 2, 1, 3], 1=>0, 2=>4, count=2)
4-element Vector{Int64}:
 0
 4
 1
 3

julia> replace([1, missing], missing=>0)
2-element Vector{Int64}:
 1
 0
```
"""
function replace(A, old_new::Pair...; count::Union{Integer,Nothing}=nothing)
    V = promote_valuetype(old_new...)
    if count isa Nothing
        T = promote_type(subtract_singletontype(eltype(A), old_new...), V)
        replace_pairs!(_similar_or_copy(A, T), A, typemax(Int), old_new)
    else
        U = promote_type(eltype(A), V)
        replace_pairs!(_similar_or_copy(A, U), A, check_count(count), old_new)
    end
end

promote_valuetype(x::Pair{K, V}) where {K, V} = V
promote_valuetype(x::Pair{K, V}, y::Pair...) where {K, V} =
    promote_type(V, promote_valuetype(y...))

# Subtract singleton types which are going to be replaced
function subtract_singletontype(::Type{T}, x::Pair{K}) where {T, K}
    if issingletontype(K)
        typesplit(T, K)
    else
        T
    end
end
subtract_singletontype(::Type{T}, x::Pair{K}, y::Pair...) where {T, K} =
    subtract_singletontype(subtract_singletontype(T, y...), x)

"""
    replace(new::Union{Function, Type}, A; [count::Integer])

Return a copy of `A` where each value `x` in `A` is replaced by `new(x)`.
If `count` is specified, then replace at most `count` values in total
(replacements being defined as `new(x) !== x`).

!!! compat "Julia 1.7"
    Version 1.7 is required to replace elements of a `Tuple`.

# Examples
```jldoctest; filter = r"^\\s+\\S+\\s+=>\\s+\\d\$"m
julia> replace(x -> isodd(x) ? 2x : x, [1, 2, 3, 4])
4-element Vector{Int64}:
 2
 2
 6
 4

julia> replace(Dict(1=>2, 3=>4)) do kv
           first(kv) < 3 ? first(kv)=>3 : kv
       end
Dict{Int64, Int64} with 2 entries:
  3 => 4
  1 => 3
```
"""
replace(new::Callable, A; count::Integer=typemax(Int)) =
    _replace!(new, _similar_or_copy(A), A, check_count(count))

# Handle ambiguities
replace!(a::Callable, b::Pair; count::Integer=-1) = throw(MethodError(replace!, (a, b)))
replace!(a::Callable, b::Pair, c::Pair; count::Integer=-1) = throw(MethodError(replace!, (a, b, c)))
replace(a::Callable, b::Pair; count::Integer=-1) = throw(MethodError(replace, (a, b)))
replace(a::Callable, b::Pair, c::Pair; count::Integer=-1) = throw(MethodError(replace, (a, b, c)))

### replace! for AbstractDict/AbstractSet

askey(k, ::AbstractDict) = k.first
askey(k, ::AbstractSet) = k

function _replace!(new::Callable, res::Union{AbstractDict,AbstractSet},
                   A::Union{AbstractDict,AbstractSet}, count::Int)
    @assert res isa AbstractDict && A isa AbstractDict ||
        res isa AbstractSet && A isa AbstractSet
    count == 0 && return res
    c = 0
    if res === A # cannot replace elements while iterating over A
        repl = Pair{eltype(A),eltype(A)}[]
        for x in A
            y = new(x)
            if x !== y
                push!(repl, x => y)
                c += 1
                c == count && break
            end
        end
        for oldnew in repl
            pop!(res, askey(first(oldnew), res))
        end
        for oldnew in repl
            push!(res, last(oldnew))
        end
    else
        for x in A
            y = new(x)
            if x !== y
                pop!(res, askey(x, res))
                push!(res, y)
                c += 1
                c == count && break
            end
        end
    end
    res
end

### replace! for AbstractArray

function _replace!(new::Callable, res::AbstractArray, A::AbstractArray, count::Int)
    c = 0
    if count >= length(A) # simpler loop allows for SIMD
        if res === A # for optimization only
            for i in eachindex(A)
                @inbounds Ai = A[i]
                y = new(Ai)
                @inbounds A[i] = y
            end
        else
            for i in eachindex(A)
                @inbounds Ai = A[i]
                y = new(Ai)
                @inbounds res[i] = y
            end
        end
    else
        for i in eachindex(A)
            @inbounds Ai = A[i]
            if c < count
                y = new(Ai)
                @inbounds res[i] = y
                c += (Ai !== y)
            else
                @inbounds res[i] = Ai
            end
        end
    end
    res
end

### specialization for Dict / Set

function _replace!(new::Callable, t::Dict{K,V}, A::AbstractDict, count::Int) where {K,V}
    # we ignore A, which is supposed to be equal to the destination t,
    # as it can generally be faster to just replace inline
    count == 0 && return t
    c = 0
    news = Pair{K,V}[]
    i = skip_deleted_floor!(t)
    @inbounds while i != 0
        k1, v1 = t.keys[i], t.vals[i]
        x1 = Pair{K,V}(k1, v1)
        x2 = new(x1)
        if x1 !== x2
            k2, v2 = first(x2), last(x2)
            if isequal(k1, k2)
                t.keys[i] = k2
                t.vals[i] = v2
                t.age += 1
            else
                _delete!(t, i)
                push!(news, x2)
            end
            c += 1
            c == count && break
        end
        i = i == typemax(Int) ? 0 : skip_deleted(t, i+1)
    end
    for n in news
        push!(t, n)
    end
    t
end

function _replace!(new::Callable, t::Set{T}, ::AbstractSet, count::Int) where {T}
    _replace!(t.dict, t.dict, count) do kv
        k = first(kv)
        k2 = new(k)
        k2 === k ? kv : k2 => nothing
    end
    t
end

### replace for tuples

function _replace(f::Callable, t::Tuple, count::Int)
    if count == 0 || isempty(t)
        t
    else
        x = f(t[1])
        (x, _replace(f, tail(t), count - !==(x, t[1]))...)
    end
end

replace(f::Callable, t::Tuple; count::Integer=typemax(Int)) =
    _replace(f, t, check_count(count))

function _replace(t::Tuple, count::Int, old_new::Tuple{Vararg{Pair}})
    _replace(t, count) do x
        @inline
        for o_n in old_new
            isequal(first(o_n), x) && return last(o_n)
        end
        return x
    end
end

replace(t::Tuple, old_new::Pair...; count::Integer=typemax(Int)) =
    _replace(t, check_count(count), old_new)
