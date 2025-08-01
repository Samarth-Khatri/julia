# This file is a part of Julia. License is MIT: https://julialang.org/license

"""
Gives a reinterpreted view (of element type T) of the underlying array (of element type S).
If the size of `T` differs from the size of `S`, the array will be compressed/expanded in
the first dimension. The variant `reinterpret(reshape, T, a)` instead adds or consumes the first dimension
depending on the ratio of element sizes.
"""
struct ReinterpretArray{T,N,S,A<:AbstractArray{S},IsReshaped} <: AbstractArray{T, N}
    parent::A
    readable::Bool
    writable::Bool

    function throwbits(S::Type, T::Type, U::Type)
        @noinline
        throw(ArgumentError(LazyString("cannot reinterpret `", S, "` as `", T, "`, type `", U, "` is not a bits type")))
    end
    function throwsize0(S::Type, T::Type, msg)
        @noinline
        throw(ArgumentError(LazyString("cannot reinterpret a zero-dimensional `", S, "` array to `", T,
            "` which is of a ", msg, " size")))
    end
    function throwsingleton(S::Type, T::Type)
        @noinline
        throw(ArgumentError(LazyString("cannot reinterpret a `", S, "` array to `", T, "` which is a singleton type")))
    end

    global reinterpret

    @doc """
        reinterpret(T::DataType, A::AbstractArray)

    Construct a view of the array with the same binary data as the given
    array, but with `T` as element type.

    This function also works on "lazy" array whose elements are not computed until they are explicitly retrieved.
    For instance, `reinterpret` on the range `1:6` works similarly as on the dense vector `collect(1:6)`:

    ```jldoctest
    julia> reinterpret(Float32, UInt32[1 2 3 4 5])
    1×5 reinterpret(Float32, ::Matrix{UInt32}):
     1.0f-45  3.0f-45  4.0f-45  6.0f-45  7.0f-45

    julia> reinterpret(Complex{Int}, 1:6)
    3-element reinterpret(Complex{$Int}, ::UnitRange{$Int}):
     1 + 2im
     3 + 4im
     5 + 6im
    ```

    If the location of padding bits does not line up between `T` and `eltype(A)`, the resulting array will be
    read-only or write-only, to prevent invalid bits from being written to or read from, respectively.

    ```jldoctest
    julia> a = reinterpret(Tuple{UInt8, UInt32}, UInt32[1, 2])
    1-element reinterpret(Tuple{UInt8, UInt32}, ::Vector{UInt32}):
     (0x01, 0x00000002)

    julia> a[1] = 3
    ERROR: Padding of type Tuple{UInt8, UInt32} is not compatible with type UInt32.

    julia> b = reinterpret(UInt32, Tuple{UInt8, UInt32}[(0x01, 0x00000002)]); # showing will error

    julia> b[1]
    ERROR: Padding of type UInt32 is not compatible with type Tuple{UInt8, UInt32}.
    ```
    """
    function reinterpret(::Type{T}, a::A) where {T,N,S,A<:AbstractArray{S, N}}
        function thrownonint(S::Type, T::Type, dim)
            @noinline
            throw(ArgumentError(LazyString(
                "cannot reinterpret an `", S, "` array to `", T, "` whose first dimension has size `", dim,
                "`. The resulting array would have a non-integral first dimension.")))
        end
        function throwaxes1(S::Type, T::Type, ax1)
            @noinline
            throw(ArgumentError(LazyString("cannot reinterpret a `", S, "` array to `", T,
                "` when the first axis is ", ax1, ". Try reshaping first.")))
        end
        isbitstype(T) || throwbits(S, T, T)
        isbitstype(S) || throwbits(S, T, S)
        (N != 0 || sizeof(T) == sizeof(S)) || throwsize0(S, T, "different")
        if N != 0 && sizeof(S) != sizeof(T)
            ax1 = axes(a)[1]
            dim = length(ax1)
            if issingletontype(T)
                issingletontype(S) || throwsingleton(S, T)
            else
                rem(dim*sizeof(S),sizeof(T)) == 0 || thrownonint(S, T, dim)
            end
            first(ax1) == 1 || throwaxes1(S, T, ax1)
        end
        readable = array_subpadding(T, S)
        writable = array_subpadding(S, T)
        new{T, N, S, A, false}(a, readable, writable)
    end
    reinterpret(::Type{T}, a::AbstractArray{T}) where {T} = a

    # With reshaping
    function reinterpret(::typeof(reshape), ::Type{T}, a::A) where {T,S,A<:AbstractArray{S}}
        function throwintmult(S::Type, T::Type)
            @noinline
            throw(ArgumentError(LazyString("`reinterpret(reshape, T, a)` requires that one of `sizeof(T)` (got ",
                sizeof(T), ") and `sizeof(eltype(a))` (got ", sizeof(S), ") be an integer multiple of the other")))
        end
        function throwsize1(a::AbstractArray, T::Type)
            @noinline
            throw(ArgumentError(LazyString("`reinterpret(reshape, ", T, ", a)` where `eltype(a)` is ", eltype(a),
                " requires that `axes(a, 1)` (got ", axes(a, 1), ") be equal to 1:",
                sizeof(T) ÷ sizeof(eltype(a)), " (from the ratio of element sizes)")))
        end
        function throwfromsingleton(S, T)
            @noinline
            throw(ArgumentError(LazyString("`reinterpret(reshape, ", T, ", a)` where `eltype(a)` is ", S,
                " requires that ", T, " be a singleton type, since ", S, " is one")))
        end
        isbitstype(T) || throwbits(S, T, T)
        isbitstype(S) || throwbits(S, T, S)
        if sizeof(S) == sizeof(T)
            N = ndims(a)
        elseif sizeof(S) > sizeof(T)
            issingletontype(T) && throwsingleton(S, T)
            rem(sizeof(S), sizeof(T)) == 0 || throwintmult(S, T)
            N = ndims(a) + 1
        else
            issingletontype(S) && throwfromsingleton(S, T)
            rem(sizeof(T), sizeof(S)) == 0 || throwintmult(S, T)
            N = ndims(a) - 1
            N > -1 || throwsize0(S, T, "larger")
            axes(a, 1) == OneTo(sizeof(T) ÷ sizeof(S)) || throwsize1(a, T)
        end
        readable = array_subpadding(T, S)
        writable = array_subpadding(S, T)
        new{T, N, S, A, true}(a, readable, writable)
    end
    reinterpret(::typeof(reshape), ::Type{T}, a::AbstractArray{T}) where {T} = a
end

ReshapedReinterpretArray{T,N,S,A<:AbstractArray{S}} = ReinterpretArray{T,N,S,A,true}
NonReshapedReinterpretArray{T,N,S,A<:AbstractArray{S, N}} = ReinterpretArray{T,N,S,A,false}

"""
    reinterpret(reshape, T, A::AbstractArray{S}) -> B

Change the type-interpretation of `A` while consuming or adding a "channel dimension."

If `sizeof(T) = n*sizeof(S)` for `n>1`, `A`'s first dimension must be
of size `n` and `B` lacks `A`'s first dimension. Conversely, if `sizeof(S) = n*sizeof(T)` for `n>1`,
`B` gets a new first dimension of size `n`. The dimensionality is unchanged if `sizeof(T) == sizeof(S)`.

!!! compat "Julia 1.6"
    This method requires at least Julia 1.6.

# Examples

```jldoctest
julia> A = [1 2; 3 4]
2×2 Matrix{$Int}:
 1  2
 3  4

julia> reinterpret(reshape, Complex{Int}, A)    # the result is a vector
2-element reinterpret(reshape, Complex{$Int}, ::Matrix{$Int}) with eltype Complex{$Int}:
 1 + 3im
 2 + 4im

julia> a = [(1,2,3), (4,5,6)]
2-element Vector{Tuple{$Int, $Int, $Int}}:
 (1, 2, 3)
 (4, 5, 6)

julia> reinterpret(reshape, Int, a)             # the result is a matrix
3×2 reinterpret(reshape, $Int, ::Vector{Tuple{$Int, $Int, $Int}}) with eltype $Int:
 1  4
 2  5
 3  6
```
"""
reinterpret(::typeof(reshape), T::Type, a::AbstractArray)

reinterpret(::Type{T}, a::NonReshapedReinterpretArray) where {T} = reinterpret(T, a.parent)
reinterpret(::typeof(reshape), ::Type{T}, a::ReshapedReinterpretArray) where {T} = reinterpret(reshape, T, a.parent)

# Definition of StridedArray
StridedFastContiguousSubArray{T,N,A<:DenseArray} = FastContiguousSubArray{T,N,A}
StridedReinterpretArray{T,N,A<:Union{DenseArray,StridedFastContiguousSubArray},IsReshaped} = ReinterpretArray{T,N,S,A,IsReshaped} where S
StridedReshapedArray{T,N,A<:Union{DenseArray,StridedFastContiguousSubArray,StridedReinterpretArray}} = ReshapedArray{T,N,A}
StridedSubArray{T,N,A<:Union{DenseArray,StridedReshapedArray,StridedReinterpretArray},
    I<:Tuple{Vararg{Union{RangeIndex, ReshapedUnitRange, AbstractCartesianIndex}}}} = SubArray{T,N,A,I}
StridedArray{T,N} = Union{DenseArray{T,N}, StridedSubArray{T,N}, StridedReshapedArray{T,N}, StridedReinterpretArray{T,N}}
StridedVector{T} = StridedArray{T,1}
StridedMatrix{T} = StridedArray{T,2}
StridedVecOrMat{T} = Union{StridedVector{T}, StridedMatrix{T}}

strides(a::Union{DenseArray,StridedReshapedArray,StridedReinterpretArray}) = size_to_strides(1, size(a)...)
stride(A::Union{DenseArray,StridedReshapedArray,StridedReinterpretArray}, k::Integer) =
    k ≤ ndims(A) ? strides(A)[k] : length(A)

function strides(a::ReinterpretArray{T,<:Any,S,<:AbstractArray{S},IsReshaped}) where {T,S,IsReshaped}
    _checkcontiguous(Bool, a) && return size_to_strides(1, size(a)...)
    stp = strides(parent(a))
    els, elp = sizeof(T), sizeof(S)
    els == elp && return stp # 0dim parent is also handled here.
    IsReshaped && els < elp && return (1, _checked_strides(stp, els, elp)...)
    stp[1] == 1 || throw(ArgumentError("Parent must be contiguous in the 1st dimension!"))
    st′ = _checked_strides(tail(stp), els, elp)
    return IsReshaped ? st′ : (1, st′...)
end

@inline function _checked_strides(stp::Tuple, els::Integer, elp::Integer)
    if elp > els && rem(elp, els) == 0
        N = div(elp, els)
        return map(i -> N * i, stp)
    end
    drs = map(i -> divrem(elp * i, els), stp)
    all(i->iszero(i[2]), drs) ||
        throw(ArgumentError("Parent's strides could not be exactly divided!"))
    map(first, drs)
end

_checkcontiguous(::Type{Bool}, A::ReinterpretArray) = _checkcontiguous(Bool, parent(A))

similar(a::ReinterpretArray, T::Type, d::Dims) = similar(a.parent, T, d)

function check_readable(a::ReinterpretArray{T, N, S} where N) where {T,S}
    # See comment in check_writable
    if !a.readable && !array_subpadding(T, S)
        throw(PaddingError(T, S))
    end
end

function check_writable(a::ReinterpretArray{T, N, S} where N) where {T,S}
    # `array_subpadding` is relatively expensive (compared to a simple arrayref),
    # so it is cached in the array. However, it is computable at compile time if,
    # inference has the types available. By using this form of the check, we can
    # get the best of both worlds for the success case. If the types were not
    # available to inference, we simply need to check the field (relatively cheap)
    # and if they were we should be able to fold this check away entirely.
    if !a.writable && !array_subpadding(S, T)
        throw(PaddingError(T, S))
    end
end

## IndexStyle specializations

# For `reinterpret(reshape, T, a)` where we're adding a channel dimension and with
# `IndexStyle(a) == IndexLinear()`, it's advantageous to retain pseudo-linear indexing.
struct IndexSCartesian2{K} <: IndexStyle end   # K = sizeof(S) ÷ sizeof(T), a static-sized 2d cartesian iterator

IndexStyle(::Type{ReinterpretArray{T,N,S,A,false}}) where {T,N,S,A<:AbstractArray{S,N}} = IndexStyle(A)
function IndexStyle(::Type{ReinterpretArray{T,N,S,A,true}}) where {T,N,S,A<:AbstractArray{S}}
    if sizeof(T) < sizeof(S)
        IndexStyle(A) === IndexLinear() && return IndexSCartesian2{sizeof(S) ÷ sizeof(T)}()
        return IndexCartesian()
    end
    return IndexStyle(A)
end
IndexStyle(::IndexSCartesian2{K}, ::IndexSCartesian2{K}) where {K} = IndexSCartesian2{K}()

struct SCartesianIndex2{K}   # can't make <:AbstractCartesianIndex without N, and 2 would be a bit misleading
    i::Int
    j::Int
end
to_index(i::SCartesianIndex2) = i

struct SCartesianIndices2{K,R<:AbstractUnitRange{Int}} <: AbstractMatrix{SCartesianIndex2{K}}
    indices2::R
end
SCartesianIndices2{K}(indices2::AbstractUnitRange{Int}) where {K} = (@assert K::Int > 1; SCartesianIndices2{K,typeof(indices2)}(indices2))

eachindex(::IndexSCartesian2{K}, A::ReshapedReinterpretArray) where {K} = SCartesianIndices2{K}(eachindex(IndexLinear(), parent(A)))
@inline function eachindex(style::IndexSCartesian2{K}, A::AbstractArray, B::AbstractArray...) where {K}
    iter = eachindex(style, A)
    itersBs = map(C->eachindex(style, C), B)
    all(==(iter), itersBs) || throw_eachindex_mismatch_indices("axes", axes(A), map(axes, B)...)
    return iter
end

size(iter::SCartesianIndices2{K}) where K = (K, length(iter.indices2))
axes(iter::SCartesianIndices2{K}) where K = (OneTo(K), iter.indices2)

first(iter::SCartesianIndices2{K}) where {K} = SCartesianIndex2{K}(1, first(iter.indices2))
last(iter::SCartesianIndices2{K}) where {K}  = SCartesianIndex2{K}(K, last(iter.indices2))

@inline function getindex(iter::SCartesianIndices2{K}, i::Int, j::Int) where {K}
    @boundscheck checkbounds(iter, i, j)
    return SCartesianIndex2{K}(i, iter.indices2[j])
end

function iterate(iter::SCartesianIndices2{K}) where {K}
    ret = iterate(iter.indices2)
    ret === nothing && return nothing
    item2, state2 = ret
    return SCartesianIndex2{K}(1, item2), (1, item2, state2)
end

function iterate(iter::SCartesianIndices2{K}, (state1, item2, state2)) where {K}
    if state1 < K
        item1 = state1 + 1
        return SCartesianIndex2{K}(item1, item2), (item1, item2, state2)
    end
    ret = iterate(iter.indices2, state2)
    ret === nothing && return nothing
    item2, state2 = ret
    return SCartesianIndex2{K}(1, item2), (1, item2, state2)
end

SimdLoop.simd_outer_range(iter::SCartesianIndices2) = iter.indices2
SimdLoop.simd_inner_length(::SCartesianIndices2{K}, ::Any) where K = K
@inline function SimdLoop.simd_index(::SCartesianIndices2{K}, Ilast::Int, I1::Int) where {K}
    SCartesianIndex2{K}(I1+1, Ilast)
end

_maybe_reshape(::IndexSCartesian2, A::AbstractArray, I...) = _maybe_reshape(IndexCartesian(), A, I...)
_maybe_reshape(::IndexSCartesian2, A::ReshapedReinterpretArray, I...) = A

# fallbacks
function _getindex(::IndexSCartesian2, A::AbstractArray, I::Vararg{Int, N}) where {N}
    @_propagate_inbounds_meta
    _getindex(IndexCartesian(), A, I...)
end
function _setindex!(::IndexSCartesian2, A::AbstractArray, v, I::Vararg{Int, N}) where {N}
    @_propagate_inbounds_meta
    _setindex!(IndexCartesian(), A, v, I...)
end
# fallbacks for array types that use "pass-through" indexing (e.g., `IndexStyle(A) = IndexStyle(parent(A))`)
# but which don't handle SCartesianIndex2
function _getindex(::IndexSCartesian2, A::AbstractArray{T,N}, ind::SCartesianIndex2) where {T,N}
    @_propagate_inbounds_meta
    J = _ind2sub(tail(axes(A)), ind.j)
    getindex(A, ind.i, J...)
end

function _getindex(::IndexSCartesian2{2}, A::AbstractArray{T,2}, ind::SCartesianIndex2) where {T}
    @_propagate_inbounds_meta
    J = first(axes(A, 2)) + ind.j - 1
    getindex(A, ind.i, J)
end

function _setindex!(::IndexSCartesian2, A::AbstractArray{T,N}, v, ind::SCartesianIndex2) where {T,N}
    @_propagate_inbounds_meta
    J = _ind2sub(tail(axes(A)), ind.j)
    setindex!(A, v, ind.i, J...)
end

function _setindex!(::IndexSCartesian2{2}, A::AbstractArray{T,2}, v, ind::SCartesianIndex2) where {T}
    @_propagate_inbounds_meta
    J = first(axes(A, 2)) + ind.j - 1
    setindex!(A, v, ind.i, J)
end

eachindex(style::IndexSCartesian2, A::AbstractArray) = eachindex(style, parent(A))

## AbstractArray interface

parent(a::ReinterpretArray) = a.parent
dataids(a::ReinterpretArray) = dataids(a.parent)
unaliascopy(a::NonReshapedReinterpretArray{T}) where {T} = reinterpret(T, unaliascopy(a.parent))
unaliascopy(a::ReshapedReinterpretArray{T}) where {T} = reinterpret(reshape, T, unaliascopy(a.parent))

function size(a::NonReshapedReinterpretArray{T,N,S} where {N}) where {T,S}
    psize = size(a.parent)
    size1 = issingletontype(T) ? psize[1] : div(psize[1]*sizeof(S), sizeof(T))
    tuple(size1, tail(psize)...)
end
function size(a::ReshapedReinterpretArray{T,N,S} where {N}) where {T,S}
    psize = size(a.parent)
    sizeof(S) > sizeof(T) && return (div(sizeof(S), sizeof(T)), psize...)
    sizeof(S) < sizeof(T) && return tail(psize)
    return psize
end
size(a::NonReshapedReinterpretArray{T,0}) where {T} = ()

function axes(a::NonReshapedReinterpretArray{T,N,S} where {N}) where {T,S}
    paxs = axes(a.parent)
    f, l = first(paxs[1]), length(paxs[1])
    size1 = issingletontype(T) ? l : div(l*sizeof(S), sizeof(T))
    tuple(oftype(paxs[1], f:f+size1-1), tail(paxs)...)
end
function axes(a::ReshapedReinterpretArray{T,N,S} where {N}) where {T,S}
    paxs = axes(a.parent)
    sizeof(S) > sizeof(T) && return (OneTo(div(sizeof(S), sizeof(T))), paxs...)
    sizeof(S) < sizeof(T) && return tail(paxs)
    return paxs
end
axes(a::NonReshapedReinterpretArray{T,0}) where {T} = ()

has_offset_axes(a::ReinterpretArray) = has_offset_axes(a.parent)

elsize(::Type{<:ReinterpretArray{T}}) where {T} = sizeof(T)
cconvert(::Type{Ptr{T}}, a::ReinterpretArray{T,N,S} where N) where {T,S} = cconvert(Ptr{S}, a.parent)
unsafe_convert(::Type{Ptr{T}}, a::ReinterpretArray{T,N,S} where N) where {T,S} = Ptr{T}(unsafe_convert(Ptr{S},a.parent))

@propagate_inbounds function getindex(a::NonReshapedReinterpretArray{T,0,S}) where {T,S}
    if isprimitivetype(T) && isprimitivetype(S)
        reinterpret(T, a.parent[])
    else
        a[firstindex(a)]
    end
end

check_ptr_indexable(a::ReinterpretArray, sz = elsize(a)) = check_ptr_indexable(parent(a), sz)
check_ptr_indexable(a::ReshapedArray, sz) = check_ptr_indexable(parent(a), sz)
check_ptr_indexable(a::FastContiguousSubArray, sz) = check_ptr_indexable(parent(a), sz)
check_ptr_indexable(a::Array, sz) = sizeof(eltype(a)) !== sz
check_ptr_indexable(a::Memory, sz) = true
check_ptr_indexable(a::AbstractArray, sz) = false

@propagate_inbounds getindex(a::ReshapedReinterpretArray{T,0}) where {T} = a[firstindex(a)]

@propagate_inbounds isassigned(a::ReinterpretArray, inds::Integer...) = checkbounds(Bool, a, inds...) && (check_ptr_indexable(a) || _isassigned_ra(a, inds...))
@propagate_inbounds isassigned(a::ReinterpretArray, inds::SCartesianIndex2) = isassigned(a.parent, inds.j)
@propagate_inbounds _isassigned_ra(a::ReinterpretArray, inds...) = true # that is not entirely true, but computing exactly which indexes will be accessed in the parent requires a lot of duplication from the _getindex_ra code

@propagate_inbounds function getindex(a::ReinterpretArray{T,N,S}, inds::Vararg{Int, N}) where {T,N,S}
    check_readable(a)
    check_ptr_indexable(a) && return _getindex_ptr(a, inds...)
    _getindex_ra(a, inds[1], tail(inds))
end

@propagate_inbounds function getindex(a::ReinterpretArray{T,N,S}, i::Int) where {T,N,S}
    check_readable(a)
    check_ptr_indexable(a) && return _getindex_ptr(a, i)
    if isa(IndexStyle(a), IndexLinear)
        return _getindex_ra(a, i, ())
    end
    # Convert to full indices here, to avoid needing multiple conversions in
    # the loop in _getindex_ra
    inds = _to_subscript_indices(a, i)
    isempty(inds) ? _getindex_ra(a, firstindex(a), ()) : _getindex_ra(a, inds[1], tail(inds))
end

@propagate_inbounds function getindex(a::ReshapedReinterpretArray{T,N,S}, ind::SCartesianIndex2) where {T,N,S}
    check_readable(a)
    s = Ref{S}(a.parent[ind.j])
    tptr = Ptr{T}(unsafe_convert(Ref{S}, s))
    GC.@preserve s return unsafe_load(tptr, ind.i)
end

@inline function _getindex_ptr(a::ReinterpretArray{T}, inds...) where {T}
    @boundscheck checkbounds(a, inds...)
    li = _to_linear_index(a, inds...)
    ap = cconvert(Ptr{T}, a)
    p = unsafe_convert(Ptr{T}, ap) + sizeof(T) * (li - 1)
    GC.@preserve ap return unsafe_load(p)
end

@propagate_inbounds function _getindex_ra(a::NonReshapedReinterpretArray{T,N,S}, i1::Int, tailinds::TT) where {T,N,S,TT}
    # Make sure to match the scalar reinterpret if that is applicable
    if sizeof(T) == sizeof(S) && (fieldcount(T) + fieldcount(S)) == 0
        if issingletontype(T) # singleton types
            @boundscheck checkbounds(a, i1, tailinds...)
            return T.instance
        end
        return reinterpret(T, a.parent[i1, tailinds...])
    else
        @boundscheck checkbounds(a, i1, tailinds...)
        ind_start, sidx = divrem((i1-1)*sizeof(T), sizeof(S))
        # Optimizations that avoid branches
        if sizeof(T) % sizeof(S) == 0
            # T is bigger than S and contains an integer number of them
            n = sizeof(T) ÷ sizeof(S)
            t = Ref{T}()
            GC.@preserve t begin
                sptr = Ptr{S}(unsafe_convert(Ref{T}, t))
                for i = 1:n
                     s = a.parent[ind_start + i, tailinds...]
                     unsafe_store!(sptr, s, i)
                end
            end
            return t[]
        elseif sizeof(S) % sizeof(T) == 0
            # S is bigger than T and contains an integer number of them
            s = Ref{S}(a.parent[ind_start + 1, tailinds...])
            GC.@preserve s begin
                tptr = Ptr{T}(unsafe_convert(Ref{S}, s))
                return unsafe_load(tptr + sidx)
            end
        else
            i = 1
            nbytes_copied = 0
            # This is a bit complicated to deal with partial elements
            # at both the start and the end. LLVM will fold as appropriate,
            # once it knows the data layout
            s = Ref{S}()
            t = Ref{T}()
            GC.@preserve s t begin
                sptr = Ptr{S}(unsafe_convert(Ref{S}, s))
                tptr = Ptr{T}(unsafe_convert(Ref{T}, t))
                while nbytes_copied < sizeof(T)
                    s[] = a.parent[ind_start + i, tailinds...]
                    nb = min(sizeof(S) - sidx, sizeof(T)-nbytes_copied)
                    memcpy(tptr + nbytes_copied, sptr + sidx, nb)
                    nbytes_copied += nb
                    sidx = 0
                    i += 1
                end
            end
            return t[]
        end
    end
end

@propagate_inbounds function _getindex_ra(a::ReshapedReinterpretArray{T,N,S}, i1::Int, tailinds::TT) where {T,N,S,TT}
    # Make sure to match the scalar reinterpret if that is applicable
    if sizeof(T) == sizeof(S) && (fieldcount(T) + fieldcount(S)) == 0
        if issingletontype(T) # singleton types
            @boundscheck checkbounds(a, i1, tailinds...)
            return T.instance
        end
        return reinterpret(T, a.parent[i1, tailinds...])
    end
    @boundscheck checkbounds(a, i1, tailinds...)
    if sizeof(T) >= sizeof(S)
        t = Ref{T}()
        GC.@preserve t begin
            sptr = Ptr{S}(unsafe_convert(Ref{T}, t))
            if sizeof(T) > sizeof(S)
                # Extra dimension in the parent array
                n = sizeof(T) ÷ sizeof(S)
                if isempty(tailinds) && IndexStyle(a.parent) === IndexLinear()
                    offset = n * (i1 - firstindex(a))
                    for i = 1:n
                        s = a.parent[i + offset]
                        unsafe_store!(sptr, s, i)
                    end
                else
                    for i = 1:n
                        s = a.parent[i, i1, tailinds...]
                        unsafe_store!(sptr, s, i)
                    end
                end
            else
                # No extra dimension
                s = a.parent[i1, tailinds...]
                unsafe_store!(sptr, s)
            end
        end
        return t[]
    end
    # S is bigger than T and contains an integer number of them
    # n = sizeof(S) ÷ sizeof(T)
    s = Ref{S}()
    GC.@preserve s begin
        tptr = Ptr{T}(unsafe_convert(Ref{S}, s))
        s[] = a.parent[tailinds...]
        return unsafe_load(tptr, i1)
    end
end

@propagate_inbounds function setindex!(a::NonReshapedReinterpretArray{T,0,S}, v) where {T,S}
    if isprimitivetype(S) && isprimitivetype(T)
        a.parent[] = reinterpret(S, convert(T, v)::T)
        return a
    end
    setindex!(a, v, firstindex(a))
end

@propagate_inbounds setindex!(a::ReshapedReinterpretArray{T,0}, v) where {T} = setindex!(a, v, firstindex(a))

@propagate_inbounds function setindex!(a::ReinterpretArray{T,N,S}, v, inds::Vararg{Int, N}) where {T,N,S}
    check_writable(a)
    check_ptr_indexable(a) && return _setindex_ptr!(a, v, inds...)
    _setindex_ra!(a, v, inds[1], tail(inds))
end

@propagate_inbounds function setindex!(a::ReinterpretArray{T,N,S}, v, i::Int) where {T,N,S}
    check_writable(a)
    check_ptr_indexable(a) && return _setindex_ptr!(a, v, i)
    if isa(IndexStyle(a), IndexLinear)
        return _setindex_ra!(a, v, i, ())
    end
    inds = _to_subscript_indices(a, i)
    isempty(inds) ? _setindex_ra!(a, v, firstindex(a), ()) : _setindex_ra!(a, v, inds[1], tail(inds))
end

@propagate_inbounds function setindex!(a::ReshapedReinterpretArray{T,N,S}, v, ind::SCartesianIndex2) where {T,N,S}
    check_writable(a)
    v = convert(T, v)::T
    s = Ref{S}(a.parent[ind.j])
    GC.@preserve s begin
        tptr = Ptr{T}(unsafe_convert(Ref{S}, s))
        unsafe_store!(tptr, v, ind.i)
    end
    a.parent[ind.j] = s[]
    return a
end

@inline function _setindex_ptr!(a::ReinterpretArray{T}, v, inds...) where {T}
    @boundscheck checkbounds(a, inds...)
    li = _to_linear_index(a, inds...)
    ap = cconvert(Ptr{T}, a)
    p = unsafe_convert(Ptr{T}, ap) + sizeof(T) * (li - 1)
    GC.@preserve ap unsafe_store!(p, v)
    return a
end

@propagate_inbounds function _setindex_ra!(a::NonReshapedReinterpretArray{T,N,S}, v, i1::Int, tailinds::TT) where {T,N,S,TT}
    v = convert(T, v)::T
    # Make sure to match the scalar reinterpret if that is applicable
    if sizeof(T) == sizeof(S) && (fieldcount(T) + fieldcount(S)) == 0
        if issingletontype(T) # singleton types
            @boundscheck checkbounds(a, i1, tailinds...)
            # setindex! is a noop except for the index check
        else
            setindex!(a.parent, reinterpret(S, v), i1, tailinds...)
        end
    else
        @boundscheck checkbounds(a, i1, tailinds...)
        ind_start, sidx = divrem((i1-1)*sizeof(T), sizeof(S))
        # Optimizations that avoid branches
        if sizeof(T) % sizeof(S) == 0
            # T is bigger than S and contains an integer number of them
            t = Ref{T}(v)
            GC.@preserve t begin
                sptr = Ptr{S}(unsafe_convert(Ref{T}, t))
                n = sizeof(T) ÷ sizeof(S)
                for i = 1:n
                    s = unsafe_load(sptr, i)
                    a.parent[ind_start + i, tailinds...] = s
                end
            end
        elseif sizeof(S) % sizeof(T) == 0
            # S is bigger than T and contains an integer number of them
            s = Ref{S}(a.parent[ind_start + 1, tailinds...])
            GC.@preserve s begin
                tptr = Ptr{T}(unsafe_convert(Ref{S}, s))
                unsafe_store!(tptr + sidx, v)
                a.parent[ind_start + 1, tailinds...] = s[]
            end
        else
            t = Ref{T}(v)
            s = Ref{S}()
            GC.@preserve t s begin
                tptr = Ptr{UInt8}(unsafe_convert(Ref{T}, t))
                sptr = Ptr{UInt8}(unsafe_convert(Ref{S}, s))
                nbytes_copied = 0
                i = 1
                # Deal with any partial elements at the start. We'll have to copy in the
                # element from the original array and overwrite the relevant parts
                if sidx != 0
                    s[] = a.parent[ind_start + i, tailinds...]
                    nb = min((sizeof(S) - sidx) % UInt, sizeof(T) % UInt)
                    memcpy(sptr + sidx, tptr, nb)
                    nbytes_copied += nb
                    a.parent[ind_start + i, tailinds...] = s[]
                    i += 1
                    sidx = 0
                end
                # Deal with the main body of elements
                while nbytes_copied < sizeof(T) && (sizeof(T) - nbytes_copied) > sizeof(S)
                    nb = min(sizeof(S), sizeof(T) - nbytes_copied)
                    memcpy(sptr, tptr + nbytes_copied, nb)
                    nbytes_copied += nb
                    a.parent[ind_start + i, tailinds...] = s[]
                    i += 1
                end
                # Deal with trailing partial elements
                if nbytes_copied < sizeof(T)
                    s[] = a.parent[ind_start + i, tailinds...]
                    nb = min(sizeof(S), sizeof(T) - nbytes_copied)
                    memcpy(sptr, tptr + nbytes_copied, nb)
                    a.parent[ind_start + i, tailinds...] = s[]
                end
            end
        end
    end
    return a
end

@propagate_inbounds function _setindex_ra!(a::ReshapedReinterpretArray{T,N,S}, v, i1::Int, tailinds::TT) where {T,N,S,TT}
    v = convert(T, v)::T
    # Make sure to match the scalar reinterpret if that is applicable
    if sizeof(T) == sizeof(S) && (fieldcount(T) + fieldcount(S)) == 0
        if issingletontype(T) # singleton types
            @boundscheck checkbounds(a, i1, tailinds...)
            # setindex! is a noop except for the index check
        else
            setindex!(a.parent, reinterpret(S, v), i1, tailinds...)
        end
    end
    @boundscheck checkbounds(a, i1, tailinds...)
    if sizeof(T) >= sizeof(S)
        t = Ref{T}(v)
        GC.@preserve t begin
            sptr = Ptr{S}(unsafe_convert(Ref{T}, t))
            if sizeof(T) > sizeof(S)
                # Extra dimension in the parent array
                n = sizeof(T) ÷ sizeof(S)
                if isempty(tailinds) && IndexStyle(a.parent) === IndexLinear()
                    offset = n * (i1 - firstindex(a))
                    for i = 1:n
                        s = unsafe_load(sptr, i)
                        a.parent[i + offset] = s
                    end
                else
                    for i = 1:n
                        s = unsafe_load(sptr, i)
                        a.parent[i, i1, tailinds...] = s
                    end
                end
            else # sizeof(T) == sizeof(S)
                # No extra dimension
                s = unsafe_load(sptr)
                a.parent[i1, tailinds...] = s
            end
        end
    else
        # S is bigger than T and contains an integer number of them
        s = Ref{S}()
        GC.@preserve s begin
            tptr = Ptr{T}(unsafe_convert(Ref{S}, s))
            s[] = a.parent[tailinds...]
            unsafe_store!(tptr, v, i1)
            a.parent[tailinds...] = s[]
        end
    end
    return a
end

# Padding
struct Padding
    offset::Int # 0-indexed offset of the next valid byte; sizeof(T) indicates trailing padding
    size::Int   # bytes of padding before a valid byte
end
function intersect(p1::Padding, p2::Padding)
    start = max(p1.offset, p2.offset)
    stop = min(p1.offset + p1.size, p2.offset + p2.size)
    Padding(start, max(0, stop-start))
end

struct PaddingError <: Exception
    S::Type
    T::Type
end

function showerror(io::IO, p::PaddingError)
    print(io, "Padding of type $(p.S) is not compatible with type $(p.T).")
end

"""
    CyclePadding(padding, total_size)

Cycles an iterator of `Padding` structs, restarting the padding at `total_size`.
E.g. if `padding` is all the padding in a struct and `total_size` is the total
aligned size of that array, `CyclePadding` will correspond to the padding in an
infinite vector of such structs.
"""
struct CyclePadding{P}
    padding::P
    total_size::Int
end
eltype(::Type{<:CyclePadding}) = Padding
IteratorSize(::Type{<:CyclePadding}) = IsInfinite()
isempty(cp::CyclePadding) = isempty(cp.padding)
function iterate(cp::CyclePadding)
    y = iterate(cp.padding)
    y === nothing && return nothing
    y[1], (0, y[2])
end
function iterate(cp::CyclePadding, state::Tuple)
    y = iterate(cp.padding, tail(state)...)
    y === nothing && return iterate(cp, (state[1]+cp.total_size,))
    Padding(y[1].offset+state[1], y[1].size), (state[1], tail(y)...)
end

"""
    Compute the location of padding in an isbits datatype. Recursive over the fields of that type.
"""
@assume_effects :foldable function padding(T::DataType, baseoffset::Int = 0)
    pads = Padding[]
    last_end::Int = baseoffset
    for i = 1:fieldcount(T)
        offset = baseoffset + Int(fieldoffset(T, i))
        fT = fieldtype(T, i)
        append!(pads, padding(fT, offset))
        if offset != last_end
            push!(pads, Padding(offset, offset-last_end))
        end
        last_end = offset + sizeof(fT)
    end
    if 0 < last_end - baseoffset < sizeof(T)
        push!(pads, Padding(baseoffset + sizeof(T), sizeof(T) - last_end + baseoffset))
    end
    return Core.svec(pads...)
end

function CyclePadding(T::DataType)
    a, s = datatype_alignment(T), sizeof(T)
    as = s + (a - (s % a)) % a
    pad = padding(T)
    if s != as
        pad = Core.svec(pad..., Padding(s, as - s))
    end
    CyclePadding(pad, as)
end

@assume_effects :total function array_subpadding(S, T)
    lcm_size = lcm(sizeof(S), sizeof(T))
    s, t = CyclePadding(S), CyclePadding(T)
    checked_size = 0
    # use of Stateful harms inference and makes this vulnerable to invalidation
    (pad, tstate) = let
        it = iterate(t)
        it === nothing && return true
        it
    end
    (ps, sstate) = let
        it = iterate(s)
        it === nothing && return false
        it
    end
    while checked_size < lcm_size
        while true
            # See if there's corresponding padding in S
            ps.offset > pad.offset && return false
            intersect(ps, pad) == pad && break
            ps, sstate = iterate(s, sstate)
        end
        checked_size = pad.offset + pad.size
        pad, tstate = iterate(t, tstate)
    end
    return true
end

@assume_effects :foldable function struct_subpadding(::Type{Out}, ::Type{In}) where {Out, In}
    padding(Out) == padding(In)
end

@assume_effects :foldable function packedsize(::Type{T}) where T
    pads = padding(T)
    return sizeof(T) - sum((p.size for p ∈ pads), init = 0)
end

@assume_effects :foldable ispacked(::Type{T}) where T = isempty(padding(T))

function _copytopacked!(ptr_out::Ptr{Out}, ptr_in::Ptr{In}) where {Out, In}
    writeoffset = 0
    for i ∈ 1:fieldcount(In)
        readoffset = fieldoffset(In, i)
        fT = fieldtype(In, i)
        if ispacked(fT)
            readsize = sizeof(fT)
            memcpy(ptr_out + writeoffset, ptr_in + readoffset, readsize)
            writeoffset += readsize
        else # nested padded type
            _copytopacked!(ptr_out + writeoffset, Ptr{fT}(ptr_in + readoffset))
            writeoffset += packedsize(fT)
        end
    end
end

function _copyfrompacked!(ptr_out::Ptr{Out}, ptr_in::Ptr{In}) where {Out, In}
    readoffset = 0
    for i ∈ 1:fieldcount(Out)
        writeoffset = fieldoffset(Out, i)
        fT = fieldtype(Out, i)
        if ispacked(fT)
            writesize = sizeof(fT)
            memcpy(ptr_out + writeoffset, ptr_in + readoffset, writesize)
            readoffset += writesize
        else # nested padded type
            _copyfrompacked!(Ptr{fT}(ptr_out + writeoffset), ptr_in + readoffset)
            readoffset += packedsize(fT)
        end
    end
end

@inline function _reinterpret(::Type{Out}, x::In) where {Out, In}
    # handle non-primitive types
    isbitstype(Out) || throw(ArgumentError("Target type for `reinterpret` must be isbits"))
    isbitstype(In) || throw(ArgumentError("Source type for `reinterpret` must be isbits"))
    inpackedsize = packedsize(In)
    outpackedsize = packedsize(Out)
    inpackedsize == outpackedsize ||
        throw(ArgumentError(LazyString("Packed sizes of types ", Out, " and ", In,
            " do not match; got ", outpackedsize, " and ", inpackedsize, ", respectively.")))
    in = Ref{In}(x)
    out = Ref{Out}()
    if struct_subpadding(Out, In)
        # if packed the same, just copy
        GC.@preserve in out begin
            ptr_in = unsafe_convert(Ptr{In}, in)
            ptr_out = unsafe_convert(Ptr{Out}, out)
            memcpy(ptr_out, ptr_in, sizeof(Out))
        end
        return out[]
    else
        # mismatched padding
        return _reinterpret_padding(Out, x)
    end
end

# If the code reaches this part, it needs to handle padding and is unlikely
# to compile to a noop. Therefore, we don't forcibly inline it.
function _reinterpret_padding(::Type{Out}, x::In) where {Out, In}
    inpackedsize = packedsize(In)
    in = Ref{In}(x)
    out = Ref{Out}()
    GC.@preserve in out begin
        ptr_in = unsafe_convert(Ptr{In}, in)
        ptr_out = unsafe_convert(Ptr{Out}, out)

        if fieldcount(In) > 0 && ispacked(Out)
            _copytopacked!(ptr_out, ptr_in)
        elseif fieldcount(Out) > 0 && ispacked(In)
            _copyfrompacked!(ptr_out, ptr_in)
        else
            packed = Ref{NTuple{inpackedsize, UInt8}}()
            GC.@preserve packed begin
                ptr_packed = unsafe_convert(Ptr{NTuple{inpackedsize, UInt8}}, packed)
                _copytopacked!(ptr_packed, ptr_in)
                _copyfrompacked!(ptr_out, ptr_packed)
            end
        end
    end
    return out[]
end


# Reductions with IndexSCartesian2

function _mapreduce(f::F, op::OP, style::IndexSCartesian2{K}, A::AbstractArrayOrBroadcasted) where {F,OP,K}
    inds = eachindex(style, A)
    n = size(inds)[2]
    if n == 0
        return mapreduce_empty_iter(f, op, A, IteratorEltype(A))
    else
        return mapreduce_impl(f, op, A, first(inds), last(inds))
    end
end

@noinline function mapreduce_impl(f::F, op::OP, A::AbstractArrayOrBroadcasted,
                                  ifirst::SCI, ilast::SCI, blksize::Int) where {F,OP,SCI<:SCartesianIndex2{K}} where K
    if ilast.j - ifirst.j < blksize
        # sequential portion
        @inbounds a1 = A[ifirst]
        @inbounds a2 = A[SCI(2,ifirst.j)]
        v = op(f(a1), f(a2))
        @simd for i = ifirst.i + 2 : K
            @inbounds ai = A[SCI(i,ifirst.j)]
            v = op(v, f(ai))
        end
        # Remaining columns
        for j = ifirst.j+1 : ilast.j
            @simd for i = 1:K
                @inbounds ai = A[SCI(i,j)]
                v = op(v, f(ai))
            end
        end
        return v
    else
        # pairwise portion
        jmid = ifirst.j + (ilast.j - ifirst.j) >> 1
        v1 = mapreduce_impl(f, op, A, ifirst, SCI(K,jmid), blksize)
        v2 = mapreduce_impl(f, op, A, SCI(1,jmid+1), ilast, blksize)
        return op(v1, v2)
    end
end

mapreduce_impl(f::F, op::OP, A::AbstractArrayOrBroadcasted, ifirst::SCartesianIndex2, ilast::SCartesianIndex2) where {F,OP} =
    mapreduce_impl(f, op, A, ifirst, ilast, pairwise_blocksize(f, op))
