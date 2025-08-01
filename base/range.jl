# This file is a part of Julia. License is MIT: https://julialang.org/license

(:)(a::Real, b::Real) = (:)(promote(a, b)...)

(:)(start::T, stop::T) where {T<:Real} = UnitRange{T}(start, stop)

(:)(start::T, stop::T) where {T} = (:)(start, oftype(stop >= start ? stop - start : start - stop, 1), stop)

# promote start and stop, leaving step alone
(:)(start::A, step, stop::C) where {A<:Real, C<:Real} =
    (:)(convert(promote_type(A, C), start), step, convert(promote_type(A, C), stop))

# AbstractFloat specializations
(:)(a::T, b::T) where {T<:AbstractFloat} = (:)(a, T(1), b)

(:)(a::T, b::AbstractFloat, c::T) where {T<:Real} = (:)(promote(a, b, c)...)
(:)(a::T, b::AbstractFloat, c::T) where {T<:AbstractFloat} = (:)(promote(a, b, c)...)
(:)(a::T, b::Real, c::T) where {T<:AbstractFloat} = (:)(promote(a, b, c)...)

(:)(start::T, step::T, stop::T) where {T<:AbstractFloat} =
    _colon(OrderStyle(T), ArithmeticStyle(T), start, step, stop)
(:)(start::T, step::T, stop::T) where {T<:Real} =
    _colon(OrderStyle(T), ArithmeticStyle(T), start, step, stop)
_colon(::Ordered, ::Any, start::T, step, stop::T) where {T} = StepRange(start, step, stop)
# for T<:Union{Float16,Float32,Float64} see twiceprecision.jl
_colon(::Ordered, ::ArithmeticRounds, start::T, step, stop::T) where {T} =
    StepRangeLen(start, step, convert(Integer, fld(stop - start, step)) + 1)
_colon(::Any, ::Any, start::T, step, stop::T) where {T} =
    StepRangeLen(start, step, convert(Integer, fld(stop - start, step)) + 1)

"""
    (:)(start, [step], stop)

Range operator. `a:b` constructs a range from `a` to `b` with a step size
equal to +1, which produces:

* a [`UnitRange`](@ref) when `a` and `b` are integers, or
* a [`StepRange`](@ref) when `a` and `b` are characters, or
* a [`StepRangeLen`](@ref) when `a` and/or `b` are floating-point.

`a:s:b` is similar but uses a step size of `s` (a [`StepRange`](@ref) or
[`StepRangeLen`](@ref)). See also [`range`](@ref) for more control.

To create a descending range, use `reverse(a:b)` or a negative step size, e.g. `b:-1:a`.
Otherwise, when `b < a`, an empty range will be constructed and normalized to `a:a-1`.

The operator `:` is also used in indexing to select whole dimensions, e.g. in `A[:, 1]`.

`:` is also used to [`quote`](@ref) code, e.g. `:(x + y) isa Expr` and `:x isa Symbol`.
Since `:2 isa Int`, it does *not* create a range in indexing: `v[:2] == v[2] != v[begin:2]`.
"""
(:)(start::T, step, stop::T) where {T} = _colon(start, step, stop)
(:)(start::T, step, stop::T) where {T<:Real} = _colon(start, step, stop)
# without the second method above, the first method above is ambiguous with
# (:)(start::A, step, stop::C) where {A<:Real,C<:Real}
function _colon(start::T, step, stop::T) where T
    T′ = typeof(start+zero(step))
    StepRange(convert(T′,start), step, convert(T′,stop))
end

"""
    range(start, stop, length)
    range(start, stop; length, step)
    range(start; length, stop, step)
    range(;start, length, stop, step)

Construct a specialized array with evenly spaced elements and optimized storage (an [`AbstractRange`](@ref)) from the arguments.
Mathematically a range is uniquely determined by any three of `start`, `step`, `stop` and `length`.
Valid invocations of range are:
* Call `range` with any three of `start`, `step`, `stop`, `length`.
* Call `range` with two of `start`, `stop`, `length`. In this case `step` will be assumed
  to be positive one. If both arguments are Integers, a [`UnitRange`](@ref) will be returned.
* Call `range` with one of `stop` or `length`. `start` and `step` will be assumed to be positive one.

To construct a descending range, specify a negative step size, e.g. `range(5, 1; step = -1)` => [5,4,3,2,1]. Otherwise,
a `stop` value less than the `start` value, with the default `step` of `+1`, constructs an empty range. Empty ranges
are normalized such that the `stop` is one less than the `start`, e.g. `range(5, 1) == 5:4`.

See Extended Help for additional details on the returned type.
See also [`logrange`](@ref) for logarithmically spaced points.

# Examples
```jldoctest
julia> range(1, length=100)
1:100

julia> range(1, stop=100)
1:100

julia> range(1, step=5, length=100)
1:5:496

julia> range(1, step=5, stop=100)
1:5:96

julia> range(1, 10, length=101)
1.0:0.09:10.0

julia> range(1, 100, step=5)
1:5:96

julia> range(stop=10, length=5)
6:10

julia> range(stop=10, step=1, length=5)
6:1:10

julia> range(start=1, step=1, stop=10)
1:1:10

julia> range(; length = 10)
Base.OneTo(10)

julia> range(; stop = 6)
Base.OneTo(6)

julia> range(; stop = 6.5)
1.0:1.0:6.0
```
If `length` is not specified and `stop - start` is not an integer multiple of `step`, a range that ends before `stop` will be produced.
```jldoctest
julia> range(1, 3.5, step=2)
1.0:2.0:3.0
```

Special care is taken to ensure intermediate values are computed rationally.
To avoid this induced overhead, see the [`LinRange`](@ref) constructor.

!!! compat "Julia 1.1"
    `stop` as a positional argument requires at least Julia 1.1.

!!! compat "Julia 1.7"
    The versions without keyword arguments and `start` as a keyword argument
    require at least Julia 1.7.

!!! compat "Julia 1.8"
    The versions with `stop` as a sole keyword argument,
    or `length` as a sole keyword argument require at least Julia 1.8.


# Extended Help

`range` will produce a `Base.OneTo` when the arguments are Integers and
* Only `length` is provided
* Only `stop` is provided

`range` will produce a `UnitRange` when the arguments are Integers and
* Only `start`  and `stop` are provided
* Only `length` and `stop` are provided

A `UnitRange` is not produced if `step` is provided even if specified as one.
"""
function range end

range(start; stop=nothing, length::Union{Integer,Nothing}=nothing, step=nothing) =
    _range(start, step, stop, length)
range(start, stop; length::Union{Integer,Nothing}=nothing, step=nothing) = _range(start, step, stop, length)
range(start, stop, length::Integer) = _range(start, nothing, stop, length)

range(;start=nothing, stop=nothing, length::Union{Integer, Nothing}=nothing, step=nothing) =
    _range(start, step, stop, length)

_range(start::Nothing, step::Nothing, stop::Nothing, len::Nothing) = range_error(start, step, stop, len)
_range(start::Nothing, step::Nothing, stop::Nothing, len::Any    ) = range_length(len)
_range(start::Nothing, step::Nothing, stop::Any    , len::Nothing) = range_stop(stop)
_range(start::Nothing, step::Nothing, stop::Any    , len::Any    ) = range_stop_length(stop, len)
_range(start::Nothing, step::Any    , stop::Nothing, len::Nothing) = range_error(start, step, stop, len)
_range(start::Nothing, step::Any    , stop::Nothing, len::Any    ) = range_error(start, step, stop, len)
_range(start::Nothing, step::Any    , stop::Any    , len::Nothing) = range_error(start, step, stop, len)
_range(start::Nothing, step::Any    , stop::Any    , len::Any    ) = range_step_stop_length(step, stop, len)
_range(start::Any    , step::Nothing, stop::Nothing, len::Nothing) = range_error(start, step, stop, len)
_range(start::Any    , step::Nothing, stop::Nothing, len::Any    ) = range_start_length(start, len)
_range(start::Any    , step::Nothing, stop::Any    , len::Nothing) = range_start_stop(start, stop)
_range(start::Any    , step::Nothing, stop::Any    , len::Any    ) = range_start_stop_length(start, stop, len)
_range(start::Any    , step::Any    , stop::Nothing, len::Nothing) = range_error(start, step, stop, len)
_range(start::Any    , step::Any    , stop::Nothing, len::Any    ) = range_start_step_length(start, step, len)
_range(start::Any    , step::Any    , stop::Any    , len::Nothing) = range_start_step_stop(start, step, stop)
_range(start::Any    , step::Any    , stop::Any    , len::Any    ) = range_error(start, step, stop, len)

# Length as the only argument
range_length(len::Integer) = OneTo(len)

# Stop as the only argument
range_stop(stop) = range_start_stop(oftype(stop, 1), stop)
range_stop(stop::Integer) = range_length(stop)

function range_step_stop_length(step, a, len::Integer)
    start = a - step * (len - oneunit(len))
    if start isa Signed
        # overflow in recomputing length from stop is okay
        return StepRange{typeof(start),typeof(step)}(start, step, convert(typeof(start), a))
    end
    return StepRangeLen{typeof(start),typeof(start),typeof(step)}(start, step, len)
end

# Stop and length as the only argument
function range_stop_length(a, len::Integer)
    step = oftype(a - a, 1) # assert that step is representable
    start = a - (len - oneunit(len))
    if start isa Signed
        # overflow in recomputing length from stop is okay
        return UnitRange(start, oftype(start, a))
    end
    return StepRangeLen{typeof(start),typeof(start),typeof(step)}(start, step, len)
end

# Start and length as the only argument
function range_start_length(a, len::Integer)
    step = oftype(a - a, 1) # assert that step is representable
    stop = a + (len - oneunit(len))
    if stop isa Signed
        # overflow in recomputing length from stop is okay
        return UnitRange(oftype(stop, a), stop)
    end
    return StepRangeLen{typeof(stop),typeof(a),typeof(step)}(a, step, len)
end

range_start_stop(start, stop) = start:stop

function range_start_step_length(a, step, len::Integer)
    stop = a + step * (len - oneunit(len))
    if stop isa Signed
        # overflow in recomputing length from stop is okay
        return StepRange{typeof(stop),typeof(step)}(convert(typeof(stop), a), step, stop)
    end
    return StepRangeLen{typeof(stop),typeof(a),typeof(step)}(a, step, len)
end

range_start_step_stop(start, step, stop) = start:step:stop

function range_error(start, step, stop, length)
    hasstart  = start !== nothing
    hasstep   = step  !== nothing
    hasstop   = stop  !== nothing
    haslength = start !== nothing

    hint = if hasstart && hasstep && hasstop && haslength
        "Try specifying only three arguments"
    elseif !hasstop && !haslength
        "At least one of `length` or `stop` must be specified."
    elseif !hasstep && !haslength
        "At least one of `length` or `step` must be specified."
    elseif !hasstart && !hasstop
        "At least one of `start` or `stop` must be specified."
    else
        "Try specifying more arguments."
    end

    msg = """
    Cannot construct range from arguments:
    start = $start
    step = $step
    stop = $stop
    length = $length
    $hint
    """
    throw(ArgumentError(msg))
end

## 1-dimensional ranges ##

"""
    AbstractRange{T} <: AbstractVector{T}

Supertype for linear ranges with elements of type `T`.
[`UnitRange`](@ref), [`LinRange`](@ref) and other types are subtypes of this.

All subtypes must define [`step`](@ref).
Thus [`LogRange`](@ref Base.LogRange) is not a subtype of `AbstractRange`.
"""
abstract type AbstractRange{T} <: AbstractArray{T,1} end

RangeStepStyle(::Type{<:AbstractRange}) = RangeStepIrregular()
RangeStepStyle(::Type{<:AbstractRange{<:Integer}}) = RangeStepRegular()

convert(::Type{T}, r::AbstractRange) where {T<:AbstractRange} = r isa T ? r : T(r)::T

## ordinal ranges

"""
    OrdinalRange{T, S} <: AbstractRange{T}

Supertype for ordinal ranges with elements of type `T` with
spacing(s) of type `S`. The steps should be always-exact
multiples of [`oneunit`](@ref), and `T` should be a "discrete"
type, which cannot have values smaller than `oneunit`. For example,
`Integer` or `Date` types would qualify, whereas `Float64` would not (since this
type can represent values smaller than `oneunit(Float64)`.
[`UnitRange`](@ref), [`StepRange`](@ref), and other types are subtypes of this.
"""
abstract type OrdinalRange{T,S} <: AbstractRange{T} end

"""
    AbstractUnitRange{T} <: OrdinalRange{T, T}

Supertype for ranges with a step size of [`oneunit(T)`](@ref) with elements of type `T`.
[`UnitRange`](@ref) and other types are subtypes of this.
"""
abstract type AbstractUnitRange{T} <: OrdinalRange{T,T} end

"""
    StepRange{T, S} <: OrdinalRange{T, S}

Ranges with elements of type `T` with spacing of type `S`. The step
between each element is constant, and the range is defined in terms
of a `start` and `stop` of type `T` and a `step` of type `S`. Neither
`T` nor `S` should be floating point types. The syntax `a:b:c` with `b != 0`
and `a`, `b`, and `c` all integers creates a `StepRange`.

# Examples
```jldoctest
julia> collect(StepRange(1, Int8(2), 10))
5-element Vector{Int64}:
 1
 3
 5
 7
 9

julia> typeof(StepRange(1, Int8(2), 10))
StepRange{Int64, Int8}

julia> typeof(1:3:6)
StepRange{Int64, Int64}
```
"""
struct StepRange{T,S} <: OrdinalRange{T,S}
    start::T
    step::S
    stop::T

    function StepRange{T,S}(start, step, stop) where {T,S}
        start = convert(T, start)
        step = convert(S, step)
        stop = convert(T, stop)
        return new(start, step, steprange_last(start, step, stop))
    end
end

# to make StepRange constructor inlineable, so optimizer can see `step` value
function steprange_last(start, step, stop)::typeof(stop)
    if isa(start, AbstractFloat) || isa(step, AbstractFloat)
        throw(ArgumentError("StepRange should not be used with floating point"))
    end
    if isa(start, Integer) && !isinteger(start + step)
        throw(ArgumentError("StepRange{<:Integer} cannot have non-integer step"))
    end
    z = zero(step)
    step == z && throw(ArgumentError("step cannot be zero"))

    if stop == start
        last = stop
    else
        if (step > z) != (stop > start)
            last = steprange_last_empty(start, step, stop)
        else
            # Compute absolute value of difference between `start` and `stop`
            # (to simplify handling both signed and unsigned T and checking for signed overflow):
            absdiff, absstep = stop > start ? (stop - start, step) : (start - stop, -step)

            # Compute remainder as a non-negative number:
            if absdiff isa Signed && absdiff < zero(absdiff)
                # unlikely, but handle the signed overflow case with unsigned rem
                overflow_case(absdiff, absstep) = (@noinline; convert(typeof(absdiff), unsigned(absdiff) % absstep))
                remain = overflow_case(absdiff, absstep)
            else
                remain = convert(typeof(absdiff), absdiff % absstep)
            end
            # Move `stop` closer to `start` if there is a remainder:
            last = stop > start ? stop - remain : stop + remain
        end
    end
    return last
end

function steprange_last_empty(start::Integer, step, stop)::typeof(stop)
    # empty range has a special representation where stop = start-1,
    # which simplifies arithmetic for Signed numbers
    if step > zero(step)
        last = start - oneunit(step)
    else
        last = start + oneunit(step)
    end
    return last
end
steprange_last_empty(start::Bool, step, stop) = start ⊻ (step > zero(step)) # isnegative(step) ? start : !start
# For types where x+oneunit(x) may not be well-defined use the user-given value for stop
steprange_last_empty(start, step, stop) = stop

StepRange{T}(start, step::S, stop) where {T,S} = StepRange{T,S}(start, step, stop)
StepRange(start::T, step::S, stop::T) where {T,S} = StepRange{T,S}(start, step, stop)

"""
    UnitRange{T<:Real}

A range parameterized by a `start` and `stop` of type `T`, filled
with elements spaced by `1` from `start` until `stop` is exceeded.
The syntax `a:b` with `a` and `b` both `Integer`s creates a `UnitRange`.

# Examples
```jldoctest
julia> collect(UnitRange(2.3, 5.2))
3-element Vector{Float64}:
 2.3
 3.3
 4.3

julia> typeof(1:10)
UnitRange{Int64}
```
"""
struct UnitRange{T<:Real} <: AbstractUnitRange{T}
    start::T
    stop::T
    UnitRange{T}(start::T, stop::T) where {T<:Real} = new(start, unitrange_last(start, stop))
end
UnitRange{T}(start, stop) where {T<:Real} = UnitRange{T}(convert(T, start), convert(T, stop))
UnitRange(start::T, stop::T) where {T<:Real} = UnitRange{T}(start, stop)
function UnitRange(start, stop)
    startstop_promoted = promote(start, stop)
    not_sametype((start, stop), startstop_promoted)
    UnitRange(startstop_promoted...)
end

# if stop and start are integral, we know that their difference is a multiple of 1
unitrange_last(start::Integer, stop::Integer) =
    stop >= start ? stop : convert(typeof(stop), start - oneunit(start - stop))
# otherwise, use `floor` as a more efficient way to compute modulus with step=1
unitrange_last(start, stop) =
    stop >= start ? convert(typeof(stop), start + floor(stop - start)) :
                    convert(typeof(stop), start - oneunit(start - stop))

unitrange(x::AbstractUnitRange) = UnitRange(x) # convenience conversion for promoting the range type

if isdefined(Main, :Base)
    # Constant-fold-able indexing into tuples to functionally expose Base.tail and Base.front
    function getindex(@nospecialize(t::Tuple), r::AbstractUnitRange)
        @inline
        require_one_based_indexing(r)
        if length(r) <= 10
            return ntuple(i -> t[i + first(r) - 1], length(r))
        elseif first(r) == 1
            last(r) == length(t)   && return t
            last(r) == length(t)-1 && return front(t)
            last(r) == length(t)-2 && return front(front(t))
        elseif last(r) == length(t)
            first(r) == 2 && return tail(t)
            first(r) == 3 && return tail(tail(t))
        end
        return (eltype(t)[t[ri] for ri in r]...,)
    end
end

"""
    Base.AbstractOneTo

Abstract type for ranges that start at 1 and have a step size of 1.
"""
abstract type AbstractOneTo{T} <: AbstractUnitRange{T} end

"""
    Base.OneTo(n)

Define an `AbstractUnitRange` that behaves like `1:n`, with the added
distinction that the lower limit is guaranteed (by the type system) to
be 1.
"""
struct OneTo{T<:Integer} <: AbstractOneTo{T}
    stop::T # invariant: stop >= zero(stop)
    function OneTo{T}(stop) where {T<:Integer}
        throwbool(r)  = (@noinline; throw(ArgumentError("invalid index: $r of type Bool")))
        T === Bool && throwbool(stop)
        return new(max(zero(T), stop))
    end

    function OneTo{T}(r::AbstractRange) where {T<:Integer}
        throwstart(r) = (@noinline; throw(ArgumentError("first element must be 1, got $(first(r))")))
        throwstep(r)  = (@noinline; throw(ArgumentError("step must be 1, got $(step(r))")))
        throwbool(r)  = (@noinline; throw(ArgumentError("invalid index: $r of type Bool")))
        first(r) == 1 || throwstart(r)
        step(r)  == 1 || throwstep(r)
        T === Bool && throwbool(r)
        return new(max(zero(T), last(r)))
    end

    global unchecked_oneto(stop::Integer) = new{typeof(stop)}(stop)
end
OneTo(stop::T) where {T<:Integer} = OneTo{T}(stop)
OneTo(r::AbstractRange{T}) where {T<:Integer} = OneTo{T}(r)
oneto(r) = OneTo(r)

## Step ranges parameterized by length

"""
    StepRangeLen(         ref::R, step::S, len, [offset=1]) where {  R,S}
    StepRangeLen{T,R,S}(  ref::R, step::S, len, [offset=1]) where {T,R,S}
    StepRangeLen{T,R,S,L}(ref::R, step::S, len, [offset=1]) where {T,R,S,L}

A range `r` where `r[i]` produces values of type `T` (in the first
form, `T` is deduced automatically), parameterized by a `ref`erence
value, a `step`, and the `len`gth. By default `ref` is the starting
value `r[1]`, but alternatively you can supply it as the value of
`r[offset]` for some other index `1 <= offset <= len`. The syntax `a:b`
or `a:b:c`, where any of `a`, `b`, or `c` are floating-point numbers, creates a
`StepRangeLen`.

!!! compat "Julia 1.7"
    The 4th type parameter `L` requires at least Julia 1.7.
"""
struct StepRangeLen{T,R,S,L<:Integer} <: AbstractRange{T}
    ref::R       # reference value (might be smallest-magnitude value in the range)
    step::S      # step value
    len::L       # length of the range
    offset::L    # the index of ref

    function StepRangeLen{T,R,S,L}(ref::R, step::S, len::Integer, offset::Integer = 1) where {T,R,S,L}
        if T <: Integer && !isinteger(ref + step)
            throw(ArgumentError("StepRangeLen{<:Integer} cannot have non-integer step"))
        end
        len = convert(L, len)
        len >= zero(len) || throw(ArgumentError("length cannot be negative, got $len"))
        offset = convert(L, offset)
        L1 = oneunit(typeof(len))
        L1 <= offset <= max(L1, len) || throw(ArgumentError("StepRangeLen: offset must be in [1,$len], got $offset"))
        return new(ref, step, len, offset)
    end
end

StepRangeLen{T,R,S}(ref::R, step::S, len::Integer, offset::Integer = 1) where {T,R,S} =
    StepRangeLen{T,R,S,promote_type(Int,typeof(len))}(ref, step, len, offset)
StepRangeLen(ref::R, step::S, len::Integer, offset::Integer = 1) where {R,S} =
    StepRangeLen{typeof(ref+zero(step)),R,S,promote_type(Int,typeof(len))}(ref, step, len, offset)
StepRangeLen{T}(ref::R, step::S, len::Integer, offset::Integer = 1) where {T,R,S} =
    StepRangeLen{T,R,S,promote_type(Int,typeof(len))}(ref, step, len, offset)

## range with computed step

"""
    LinRange{T,L}

A range with `len` linearly spaced elements between its `start` and `stop`.
The size of the spacing is controlled by `len`, which must
be an `Integer`.

# Examples
```jldoctest
julia> LinRange(1.5, 5.5, 9)
9-element LinRange{Float64, Int64}:
 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0, 5.5
```

Compared to using [`range`](@ref), directly constructing a `LinRange` should
have less overhead but won't try to correct for floating point errors:
```jldoctest
julia> collect(range(-0.1, 0.3, length=5))
5-element Vector{Float64}:
 -0.1
  0.0
  0.1
  0.2
  0.3

julia> collect(LinRange(-0.1, 0.3, 5))
5-element Vector{Float64}:
 -0.1
 -1.3877787807814457e-17
  0.09999999999999999
  0.19999999999999998
  0.3
```

See also [`Base.LogRange`](@ref Base.LogRange) for logarithmically spaced points.
"""
struct LinRange{T,L<:Integer} <: AbstractRange{T}
    start::T
    stop::T
    len::L
    lendiv::L

    function LinRange{T,L}(start::T, stop::T, len::L) where {T,L<:Integer}
        len >= 0 || throw(ArgumentError("range($start, stop=$stop, length=$len): negative length"))
        onelen = oneunit(typeof(len))
        if len == onelen
            start == stop || throw(ArgumentError("range($start, stop=$stop, length=$len): endpoints differ"))
            return new(start, stop, len, len)
        end
        lendiv = max(len - onelen, onelen)
        if T <: Integer && !iszero(mod(stop-start, lendiv))
            throw(ArgumentError("LinRange{<:Integer} cannot have non-integer step"))
        end
        return new(start, stop, len, lendiv)
    end
end

function LinRange{T,L}(start, stop, len::Integer) where {T,L}
    LinRange{T,L}(convert(T, start), convert(T, stop), convert(L, len))
end

function LinRange{T}(start, stop, len::Integer) where T
    LinRange{T,promote_type(Int,typeof(len))}(start, stop, len)
end

function LinRange(start, stop, len::Integer)
    T = typeof((zero(stop) - zero(start)) / oneunit(len))
    LinRange{T}(start, stop, len)
end

range_start_stop_length(start, stop, len::Integer) =
    range_start_stop_length(promote(start, stop)..., len)
range_start_stop_length(start::T, stop::T, len::Integer) where {T} = LinRange(start, stop, len)
range_start_stop_length(start::T, stop::T, len::Integer) where {T<:Integer} =
    _linspace(float(T), start, stop, len)
## for Float16, Float32, and Float64 we hit twiceprecision.jl to lift to higher precision StepRangeLen
# for all other types we fall back to a plain old LinRange
_linspace(::Type{T}, start::Integer, stop::Integer, len::Integer) where T = LinRange{T}(start, stop, len)

function show(io::IO, r::LinRange{T}) where {T}
    print(io, "LinRange{")
    show(io, T)
    print(io, "}(")
    ioc = IOContext(io, :typeinfo=>T)
    show(ioc, first(r))
    print(io, ", ")
    show(ioc, last(r))
    print(io, ", ")
    show(io, length(r))
    print(io, ')')
end

"""
`print_range(io, r)` prints out a nice looking range r in terms of its elements
as if it were `collect(r)`, dependent on the size of the
terminal, and taking into account whether compact numbers should be shown.
It figures out the width in characters of each element, and if they
end up too wide, it shows the first and last elements separated by a
horizontal ellipsis. Typical output will look like `1.0, 2.0, …, 5.0, 6.0`.

`print_range(io, r, pre, sep, post, hdots)` uses optional
parameters `pre` and `post` characters for each printed row,
`sep` separator string between printed elements,
`hdots` string for the horizontal ellipsis.
"""
function print_range(io::IO, r::AbstractArray,
                     pre::AbstractString = " ",
                     sep::AbstractString = ", ",
                     post::AbstractString = "",
                     hdots::AbstractString = ", \u2026, ") # horiz ellipsis
    # This function borrows from print_matrix() in show.jl
    # and should be called by show and display
    sz = displaysize(io)
    if !haskey(io, :compact)
        io = IOContext(io, :compact => true)
    end
    screenheight, screenwidth = sz[1] - 4, sz[2]
    screenwidth -= length(pre) + length(post)
    postsp = ""
    sepsize = length(sep)
    m = 1 # treat the range as a one-row matrix
    n = length(r)
    # Figure out spacing alignments for r, but only need to examine the
    # left and right edge columns, as many as could conceivably fit on the
    # screen, with the middle columns summarized by horz, vert, or diag ellipsis
    maxpossiblecols = div(screenwidth, 1+sepsize) # assume each element is at least 1 char + 1 separator
    colsr = n <= maxpossiblecols ? (1:n) : [1:div(maxpossiblecols,2)+1; (n-div(maxpossiblecols,2)):n]
    rowmatrix = reshape(r[colsr], 1, length(colsr)) # treat the range as a one-row matrix for print_matrix_row
    nrow, idxlast = size(rowmatrix, 2), last(axes(rowmatrix, 2))
    A = alignment(io, rowmatrix, 1:m, 1:length(rowmatrix), screenwidth, screenwidth, sepsize, nrow) # how much space range takes
    if n <= length(A) # cols fit screen, so print out all elements
        print(io, pre) # put in pre chars
        print_matrix_row(io,rowmatrix,A,1,1:n,sep,idxlast) # the entire range
        print(io, post) # add the post characters
    else # cols don't fit so put horiz ellipsis in the middle
        # how many chars left after dividing width of screen in half
        # and accounting for the horiz ellipsis
        c = div(screenwidth-length(hdots)+1,2)+1 # chars remaining for each side of rowmatrix
        alignR = reverse(alignment(io, rowmatrix, 1:m, length(rowmatrix):-1:1, c, c, sepsize, nrow)) # which cols of rowmatrix to put on the right
        c = screenwidth - sum(map(sum,alignR)) - (length(alignR)-1)*sepsize - length(hdots)
        alignL = alignment(io, rowmatrix, 1:m, 1:length(rowmatrix), c, c, sepsize, nrow) # which cols of rowmatrix to put on the left
        print(io, pre)   # put in pre chars
        print_matrix_row(io, rowmatrix,alignL,1,1:length(alignL),sep,idxlast) # left part of range
        print(io, hdots) # horizontal ellipsis
        print_matrix_row(io, rowmatrix,alignR,1,length(rowmatrix)-length(alignR)+1:length(rowmatrix),sep,idxlast) # right part of range
        print(io, post)  # post chars
    end
end

## interface implementations

length(r::AbstractRange) = error("length implementation missing") # catch mistakes
size(r::AbstractRange) = (@inline; (length(r),))

isempty(r::StepRange) =
    # steprange_last(r.start, r.step, r.stop) == r.stop
    (r.start != r.stop) & ((r.step > zero(r.step)) != (r.stop > r.start))
isempty(r::AbstractUnitRange) = first(r) > last(r)
isempty(r::StepRangeLen) = length(r) == 0
isempty(r::LinRange) = length(r) == 0

"""
    step(r)

Get the step size of an [`AbstractRange`](@ref) object.

# Examples
```jldoctest
julia> step(1:10)
1

julia> step(1:2:10)
2

julia> step(2.5:0.3:10.9)
0.3

julia> step(range(2.5, stop=10.9, length=85))
0.1
```
"""
step(r::StepRange) = r.step
step(r::AbstractUnitRange{T}) where {T} = oneunit(T) - zero(T)
step(r::AbstractUnitRange{Bool}) = true
step(r::StepRangeLen) = r.step
step(r::StepRangeLen{T}) where {T<:AbstractFloat} = T(r.step)
step(r::LinRange) = (last(r)-first(r))/r.lendiv

# high-precision step
step_hp(r::StepRangeLen) = r.step
step_hp(r::AbstractRange) = step(r)

# Needed to ensure `has_offset_axes` can constant-fold.
has_offset_axes(::StepRange) = false

# n.b. checked_length for these is defined iff checked_add and checked_sub are
# defined between the relevant types
function checked_length(r::OrdinalRange{T}) where T
    s = step(r)
    start = first(r)
    if isempty(r)
        return Integer(div(start - start, oneunit(s)))
    end
    stop = last(r)
    if isless(s, zero(s))
        diff = checked_sub(start, stop)
        s = -s
    else
        diff = checked_sub(stop, start)
    end
    a = div(diff, s)
    return Integer(checked_add(a, oneunit(a)))
end

function checked_length(r::AbstractUnitRange{T}) where T
    # compiler optimization: remove dead cases from above
    if isempty(r)
        return Integer(first(r) - first(r))
    end
    a = checked_sub(last(r), first(r))
    return Integer(checked_add(a, oneunit(a)))
end

function length(r::OrdinalRange{T}) where T
    s = step(r)
    start = first(r)
    if isempty(r)
        return Integer(div(start - start, oneunit(s)))
    end
    stop = last(r)
    if isless(s, zero(s))
        diff = start - stop
        s = -s
    else
        diff = stop - start
    end
    a = div(diff, s)
    return Integer(a + oneunit(a))
end

function length(r::AbstractUnitRange{T}) where T
    @inline
    start, stop = first(r), last(r)
    a = oneunit(zero(stop) - zero(start))
    if a isa Signed || stop >= start
        a += stop - start # Signed are allowed to go negative
    else
        a = zero(a) # Unsigned don't necessarily underflow
    end
    return Integer(a)
end

length(r::OneTo) = Integer(r.stop - zero(r.stop))
length(r::StepRangeLen) = r.len
length(r::LinRange) = r.len

let bigints = Union{Int, UInt, Int64, UInt64, Int128, UInt128},
    smallints = (Int === Int64 ?
                Union{Int8, UInt8, Int16, UInt16, Int32, UInt32} :
                Union{Int8, UInt8, Int16, UInt16}),
    bitints = Union{bigints, smallints}
    global length, checked_length, firstindex
    # compile optimization for which promote_type(T, Int) == T
    length(r::OneTo{T}) where {T<:bigints} = r.stop
    # slightly more accurate length and checked_length in extreme cases
    # (near typemax) for types with known `unsigned` functions
    function length(r::OrdinalRange{T}) where T<:bigints
        s = step(r)
        diff = last(r) - first(r)
        isempty(r) && return zero(diff)
        # Compute `(diff ÷ s) + 1` in a manner robust to signed overflow
        # by using the absolute values as unsigneds for non-empty ranges.
        # Note that `s` may be a different type from T and diff; it may not
        # even be a BitInteger that supports `unsigned`. Handle with care.
        a = div(unsigned(flipsign(diff, s)), s) % typeof(diff)
        return flipsign(a, s) + oneunit(a)
    end
    function checked_length(r::OrdinalRange{T}) where T<:bigints
        s = step(r)
        stop, start = last(r), first(r)
        ET = promote_type(typeof(stop), typeof(start))
        isempty(r) && return zero(ET)
        # n.b. !(s isa T)
        if s > 1
            diff = stop - start
            a = convert(ET, div(unsigned(diff), s))
        elseif s < -1
            diff = start - stop
            a = convert(ET, div(unsigned(diff), -s))
        elseif s > 0
            a = convert(ET, div(checked_sub(stop, start), s))
        else
            a = convert(ET, div(checked_sub(start, stop), -s))
        end
        return checked_add(a, oneunit(a))
    end
    firstindex(r::StepRange{<:bigints,<:bitints}) = one(last(r)-first(r))

    # some special cases to favor default Int type
    function length(r::OrdinalRange{<:smallints})
        s = step(r)
        isempty(r) && return 0
        # n.b. !(step isa T)
        return Int(div(Int(last(r)) - Int(first(r)), s)) + 1
    end
    length(r::AbstractUnitRange{<:smallints}) = Int(last(r)) - Int(first(r)) + 1
    length(r::OneTo{<:smallints}) = Int(r.stop)
    checked_length(r::OrdinalRange{<:smallints}) = length(r)
    checked_length(r::AbstractUnitRange{<:smallints}) = length(r)
    checked_length(r::OneTo{<:smallints}) = length(r)
    firstindex(::StepRange{<:smallints,<:bitints}) = 1
end

first(r::OrdinalRange{T}) where {T} = convert(T, r.start)
first(r::OneTo{T}) where {T} = oneunit(T)
first(r::StepRangeLen) = unsafe_getindex(r, 1)
first(r::LinRange) = r.start

function first(r::OneTo, n::Integer)
    n < 0 && throw(ArgumentError("Number of elements must be non-negative"))
    OneTo(oftype(r.stop, min(r.stop, n)))
end

last(r::OrdinalRange{T}) where {T} = convert(T, r.stop) # via steprange_last
last(r::StepRangeLen) = unsafe_getindex(r, length(r))
last(r::LinRange) = r.stop

minimum(r::AbstractUnitRange) = isempty(r) ? throw(ArgumentError("range must be non-empty")) : first(r)
maximum(r::AbstractUnitRange) = isempty(r) ? throw(ArgumentError("range must be non-empty")) : last(r)
minimum(r::AbstractRange)  = isempty(r) ? throw(ArgumentError("range must be non-empty")) : min(first(r), last(r))
maximum(r::AbstractRange)  = isempty(r) ? throw(ArgumentError("range must be non-empty")) : max(first(r), last(r))

"""
    argmin(r::AbstractRange)

Ranges can have multiple minimal elements. In that case
`argmin` will return a minimal index, but not necessarily the
first one.
"""
function argmin(r::AbstractRange)
    if isempty(r)
        throw(ArgumentError("range must be non-empty"))
    elseif step(r) > 0
        firstindex(r)
    else
        lastindex(r)
    end
end

"""
    argmax(r::AbstractRange)

Ranges can have multiple maximal elements. In that case
`argmax` will return a maximal index, but not necessarily the
first one.
"""
function argmax(r::AbstractRange)
    if isempty(r)
        throw(ArgumentError("range must be non-empty"))
    elseif step(r) > 0
        lastindex(r)
    else
        firstindex(r)
    end
end

extrema(r::AbstractRange) = (minimum(r), maximum(r))

# Ranges are immutable
copy(r::AbstractRange) = r


## iteration

function iterate(r::Union{StepRangeLen,LinRange}, i::Integer=zero(length(r)))
    @inline
    i += oneunit(i)
    length(r) < i && return nothing
    unsafe_getindex(r, i), i
end

iterate(r::OrdinalRange) = isempty(r) ? nothing : (first(r), first(r))

function iterate(r::OrdinalRange{T}, i) where {T}
    @inline
    i == last(r) && return nothing
    next = convert(T, i + step(r))
    (next, next)
end

## indexing

function isassigned(r::AbstractRange, i::Integer)
    i isa Bool && throw(ArgumentError("invalid index: $i of type Bool"))
    firstindex(r) <= i <= lastindex(r)
end

# `_getindex` is like `getindex` but does not check if `i isa Bool`
function _getindex(v::AbstractRange, i::Integer)
    @boundscheck checkbounds(v, i)
    unsafe_getindex(v, i)
end

_in_unit_range(v::UnitRange, val, i::Integer) = i > 0 && val <= v.stop && val >= v.start

function _getindex(v::UnitRange{T}, i::Integer) where T
    val = convert(T, v.start + (i - oneunit(i)))
    @boundscheck _in_unit_range(v, val, i) || throw_boundserror(v, i)
    val
end

const OverflowSafe = Union{Bool,Int8,Int16,Int32,Int64,Int128,
                           UInt8,UInt16,UInt32,UInt64,UInt128}

function _getindex(v::UnitRange{T}, i::Integer) where {T<:OverflowSafe}
    val = v.start + (i - oneunit(i))
    @boundscheck _in_unit_range(v, val, i) || throw_boundserror(v, i)
    val % T
end

let BitInteger64 = Union{Int8,Int16,Int32,Int64,UInt8,UInt16,UInt32,UInt64} # for bootstrapping
    global function checkbounds(::Type{Bool}, v::StepRange{<:BitInteger64, <:BitInteger64}, i::BitInteger64)
        res = widemul(step(v), i-oneunit(i)) + first(v)
        (0 < i) & ifelse(0 < step(v), res <= last(v), res >= last(v))
    end
end

# unsafe_getindex is separate to make it useful even when running with --check-bounds=yes
# it assumes the index is inbounds but does not segfault even if the index is out of bounds.
# it does not check if the index isa bool.
unsafe_getindex(v::OneTo{T}, i::Integer) where T = convert(T, i)
unsafe_getindex(v::AbstractRange{T}, i::Integer) where T = convert(T, first(v) + (i - oneunit(i))*step_hp(v))
function unsafe_getindex(r::StepRangeLen{T}, i::Integer) where T
    u = oftype(r.offset, i) - r.offset
    T(r.ref + u*r.step)
end
unsafe_getindex(r::LinRange, i::Integer) = lerpi(i-oneunit(i), r.lendiv, r.start, r.stop)

function lerpi(j::Integer, d::Integer, a::T, b::T) where T
    t = j/d # ∈ [0,1]
    # compute approximately fma(t, b, -fma(t, a, a))
    return T((1-t)*a + t*b)
end

# non-scalar indexing

getindex(r::AbstractRange, ::Colon) = copy(r)

function getindex(r::AbstractUnitRange, s::AbstractUnitRange{T}) where {T<:Integer}
    @inline
    @boundscheck checkbounds(r, s)

    if T === Bool
        return range(first(s) ? first(r) : last(r), length = last(s))
    else
        f = first(r)
        start = oftype(f, f + first(s) - firstindex(r))
        len = length(s)
        stop = oftype(f, start + (len - oneunit(len)))
        return range(start, stop)
    end
end

function getindex(r::OneTo{T}, s::OneTo) where T
    @inline
    @boundscheck checkbounds(r, s)
    return OneTo(T(s.stop))
end

function getindex(r::AbstractUnitRange, s::StepRange{T}) where {T<:Integer}
    @inline
    @boundscheck checkbounds(r, s)

    if T === Bool
        len = Int(last(s))
        return range(first(s) ? first(r) : last(r), step=oneunit(eltype(r)), length=len)
    else
        f = first(r)
        start = oftype(f, f + s.start - firstindex(r))
        st = step(s)
        len = length(s)
        stop = oftype(f, start + (len - oneunit(len)) * (iszero(len) ? copysign(oneunit(st), st) : st))
        return range(start, stop; step=st)
    end
end

function getindex(r::StepRange, s::AbstractRange{T}) where {T<:Integer}
    @inline
    @boundscheck checkbounds(r, s)

    if T === Bool
        # treat as a zero, one, or two-element vector, where at most one element is true
        # staying inbounds on the original range (preserving either start or
        # stop as either stop or start, depending on the length)
        st = step(s)
        nonempty = st > zero(st) ? last(s) : first(s)
        # n.b. isempty(r) implies isempty(r) which means !nonempty and !first(s)
        range((first(s) ⊻ nonempty) ⊻ isempty(r) ? last(r) : first(r), step=step(r), length=Int(nonempty))
    else
        f = r.start
        fs = first(s)
        st = r.step
        start = oftype(f, f + (fs - firstindex(r)) * st)
        st *= step(s)
        len = length(s)
        # mimic steprange_last_empty here, to try to avoid overflow
        stop = oftype(f, start + (len - oneunit(len)) * (iszero(len) ? copysign(oneunit(st), st) : st))
        return range(start, stop; step=st)
    end
end

function getindex(r::StepRangeLen{T}, s::OrdinalRange{S}) where {T, S<:Integer}
    @inline
    @boundscheck checkbounds(r, s)

    len = length(s)
    sstep = step_hp(s)
    rstep = step_hp(r)
    L = typeof(len)
    if S === Bool
        rstep *= one(sstep)
        if len == 0
            return StepRangeLen{T}(first(r), rstep, zero(L), oneunit(L))
        elseif len == 1
            if first(s)
                return StepRangeLen{T}(first(r), rstep, oneunit(L), oneunit(L))
            else
                return StepRangeLen{T}(first(r), rstep, zero(L), oneunit(L))
            end
        else # len == 2
            return StepRangeLen{T}(last(r), rstep, oneunit(L), oneunit(L))
        end
    else
        # Find closest approach to offset by s
        ind = LinearIndices(s)
        offset = L(max(min(1 + round(L, (r.offset - first(s))/sstep), last(ind)), first(ind)))
        ref = _getindex_hiprec(r, first(s) + (offset - oneunit(offset)) * sstep)
        return StepRangeLen{T}(ref, rstep*sstep, len, offset)
    end
end

function _getindex_hiprec(r::StepRangeLen, i::Integer)  # without rounding by T
    u = oftype(r.offset, i) - r.offset
    r.ref + u*r.step
end

function getindex(r::LinRange{T}, s::OrdinalRange{S}) where {T, S<:Integer}
    @inline
    @boundscheck checkbounds(r, s)

    len = length(s)
    L = typeof(len)
    if S === Bool
        if len == 0
            return LinRange{T}(first(r), first(r), len)
        elseif len == 1
            if first(s)
                return LinRange{T}(first(r), first(r), len)
            else
                return LinRange{T}(first(r), first(r), zero(L))
            end
        else # length(s) == 2
            return LinRange{T}(last(r), last(r), oneunit(L))
        end
    else
        vfirst = unsafe_getindex(r, first(s))
        vlast  = unsafe_getindex(r, last(s))
        return LinRange{T}(vfirst, vlast, len)
    end
end

show(io::IO, r::AbstractRange) = print(io, repr(first(r)), ':', repr(step(r)), ':', repr(last(r)))
function show(io::IO, r::UnitRange)
    show(io, first(r))
    print(io, ':')
    show(io, last(r))
end
show(io::IO, r::OneTo) = print(io, "Base.OneTo(", r.stop, ")")
function show(io::IO, r::StepRangeLen)
    if !iszero(step(r))
        print(io, repr(first(r)), ':', repr(step(r)), ':', repr(last(r)))
    else
        # ugly temporary printing, to avoid 0:0:0 etc.
        print(io, "StepRangeLen(", repr(first(r)), ", ", repr(step(r)), ", ", repr(length(r)), ")")
    end
end

function ==(r::T, s::T) where {T<:AbstractRange}
    isempty(r) && return isempty(s)
    _has_length_one(r) && return _has_length_one(s) & (first(r) == first(s))
    (first(r) == first(s)) & (step(r) == step(s)) & (last(r) == last(s))
end

function ==(r::OrdinalRange, s::OrdinalRange)
    isempty(r) && return isempty(s)
    _has_length_one(r) && return _has_length_one(s) & (first(r) == first(s))
    (first(r) == first(s)) & (step(r) == step(s)) & (last(r) == last(s))
end

==(r::AbstractUnitRange, s::AbstractUnitRange) =
    (isempty(r) & isempty(s)) | ((first(r) == first(s)) & (last(r) == last(s)))

==(r::OneTo, s::OneTo) = last(r) == last(s)

==(r::T, s::T) where {T<:Union{StepRangeLen,LinRange}} =
    (isempty(r) & isempty(s)) | ((first(r) == first(s)) & (length(r) == length(s)) & (last(r) == last(s)))

function ==(r::Union{StepRange{T},StepRangeLen{T,T}}, s::Union{StepRange{T},StepRangeLen{T,T}}) where {T}
    isempty(r) && return isempty(s)
    _has_length_one(r) && return _has_length_one(s) & (first(r) == first(s))
    (first(r) == first(s)) & (step(r) == step(s)) & (last(r) == last(s))
end

_has_length_one(r::OrdinalRange) = first(r) == last(r)
_has_length_one(r::AbstractRange) = isone(length(r))

function ==(r::AbstractRange, s::AbstractRange)
    lr = length(r)
    if lr != length(s)
        return false
    elseif iszero(lr)
        return true
    end
    yr, ys = iterate(r), iterate(s)
    while yr !== nothing
        yr[1] == ys[1] || return false
        yr, ys = iterate(r, yr[2]), iterate(s, ys[2])
    end
    return true
end

intersect(r::OneTo, s::OneTo) = OneTo(min(r.stop,s.stop))
union(r::OneTo, s::OneTo) = OneTo(max(r.stop,s.stop))

intersect(r::AbstractUnitRange{<:Integer}, s::AbstractUnitRange{<:Integer}) = max(first(r),first(s)):min(last(r),last(s))

intersect(i::Integer, r::AbstractUnitRange{<:Integer}) = range(max(i, first(r)), length=in(i, r))

intersect(r::AbstractUnitRange{<:Integer}, i::Integer) = intersect(i, r)

function intersect(r::AbstractUnitRange{<:Integer}, s::StepRange{<:Integer})
    T = promote_type(eltype(r), eltype(s))
    if isempty(s)
        StepRange{T}(first(r), +step(s), first(r)-step(s))
    else
        sta, ste, sto = first_step_last_ascending(s)
        lo = first(r)
        hi = last(r)
        i0 = max(sta, lo + mod(sta - lo, ste))
        i1 = min(sto, hi - mod(hi - sta, ste))
        StepRange{T}(i0, ste, i1)
    end
end

function first_step_last_ascending(r::StepRange)
    if step(r) < zero(step(r))
        last(r), -step(r), first(r)
    else
        first(r), +step(r), last(r)
    end
end

function intersect(r::StepRange{<:Integer}, s::AbstractUnitRange{<:Integer})
    if step(r) < 0
        reverse(intersect(s, reverse(r)))
    else
        intersect(s, r)
    end
end

function intersect(r::StepRange, s::StepRange)
    T = promote_type(eltype(r), eltype(s))
    S = promote_type(typeof(step(r)), typeof(step(s)))
    if isempty(r) || isempty(s)
        return StepRange{T,S}(first(r), step(r), first(r)-step(r))
    end

    start1, step1, stop1 = first_step_last_ascending(r)
    start2, step2, stop2 = first_step_last_ascending(s)
    a = lcm(step1, step2)

    g, x, y = gcdx(step1, step2)

    if !iszero(rem(start1 - start2, g))
        # Unaligned, no overlap possible.
        if  step(r) < zero(step(r))
            return StepRange{T,S}(stop1, -a, stop1+a)
        else
            return StepRange{T,S}(start1, a, start1-a)
        end
    end

    z = div(start1 - start2, g)
    b = start1 - x * z * step1
    # Possible points of the intersection of r and s are
    # ..., b-2a, b-a, b, b+a, b+2a, ...
    # Determine where in the sequence to start and stop.
    m = max(start1 + mod(b - start1, a), start2 + mod(b - start2, a))
    n = min(stop1 - mod(stop1 - b, a), stop2 - mod(stop2 - b, a))
    step(r) < zero(step(r)) ? StepRange{T,S}(n, -a, m) : StepRange{T,S}(m, a, n)
end

function intersect(r1::AbstractRange, r2::AbstractRange)
    # To iterate over the shorter range
    length(r1) > length(r2) && return intersect(r2, r1)

    r1 = unique(r1)
    T = promote_eltype(r1, r2)

    return T[x for x in r1 if x ∈ r2]
end

function intersect(r1::AbstractRange, r2::AbstractRange, r3::AbstractRange, r::AbstractRange...)
    i = intersect(intersect(r1, r2), r3)
    for t in r
        i = intersect(i, t)
    end
    i
end

# _findin (the index of intersection)
function _findin(r::AbstractRange{<:Integer}, span::AbstractUnitRange{<:Integer})
    fspan = first(span)
    lspan = last(span)
    fr = first(r)
    lr = last(r)
    sr = step(r)
    if sr > 0
        ifirst = fr >= fspan ? 1 : cld(fspan-fr, sr)+1
        ilast = lr <= lspan ? length(r) : length(r) - cld(lr-lspan, sr)
    elseif sr < 0
        ifirst = fr <= lspan ? 1 : cld(lspan-fr, sr)+1
        ilast = lr >= fspan ? length(r) : length(r) - cld(lr-fspan, sr)
    else
        ifirst = fr >= fspan ? 1 : length(r)+1
        ilast = fr <= lspan ? length(r) : 0
    end
    r isa AbstractUnitRange ? (ifirst:ilast) : (ifirst:1:ilast)
end

issubset(r::OneTo, s::OneTo) = r.stop <= s.stop

issubset(r::AbstractUnitRange{<:Integer}, s::AbstractUnitRange{<:Integer}) =
    isempty(r) || (first(r) >= first(s) && last(r) <= last(s))

## linear operations on ranges ##

-(r::OrdinalRange) = range(-first(r), step=negate(step(r)), length=length(r))
-(r::StepRangeLen{T,R,S,L}) where {T,R,S,L} =
    StepRangeLen{T,R,S,L}(-r.ref, -r.step, r.len, r.offset)
function -(r::LinRange)
    start = -r.start
    LinRange{typeof(start)}(start, -r.stop, length(r))
end

# promote eltype if at least one container wouldn't change, otherwise join container types.
el_same(::Type{T}, a::Type{<:AbstractArray{T,n}}, b::Type{<:AbstractArray{T,n}}) where {T,n}   = a # we assume a === b
el_same(::Type{T}, a::Type{<:AbstractArray{T,n}}, b::Type{<:AbstractArray{S,n}}) where {T,S,n} = a
el_same(::Type{T}, a::Type{<:AbstractArray{S,n}}, b::Type{<:AbstractArray{T,n}}) where {T,S,n} = b
el_same(::Type, a, b) = promote_typejoin(a, b)

promote_rule(a::Type{UnitRange{T1}}, b::Type{UnitRange{T2}}) where {T1,T2} =
    el_same(promote_type(T1, T2), a, b)
UnitRange{T}(r::UnitRange{T}) where {T<:Real} = r
UnitRange{T}(r::UnitRange) where {T<:Real} = UnitRange{T}(r.start, r.stop)

promote_rule(a::Type{OneTo{T1}}, b::Type{OneTo{T2}}) where {T1,T2} =
    el_same(promote_type(T1, T2), a, b)
OneTo{T}(r::OneTo{T}) where {T<:Integer} = r
OneTo{T}(r::OneTo) where {T<:Integer} = OneTo{T}(r.stop)

promote_rule(a::Type{OneTo{T1}}, ::Type{UR}) where {T1,UR<:AbstractUnitRange} =
    promote_rule(UnitRange{T1}, UR)

promote_rule(a::Type{UnitRange{T1}}, ::Type{UR}) where {T1,UR<:AbstractUnitRange} =
    promote_rule(a, UnitRange{eltype(UR)})
UnitRange{T}(r::AbstractUnitRange) where {T<:Real} = UnitRange{T}(first(r), last(r))
UnitRange(r::AbstractUnitRange) = UnitRange(first(r), last(r))

AbstractUnitRange{T}(r::AbstractUnitRange{T}) where {T} = r
AbstractUnitRange{T}(r::UnitRange) where {T} = UnitRange{T}(r)
AbstractUnitRange{T}(r::OneTo) where {T} = OneTo{T}(r)

OrdinalRange{T, S}(r::OrdinalRange) where {T, S} = StepRange{T, S}(r)
OrdinalRange{T, T}(r::AbstractUnitRange) where {T} = AbstractUnitRange{T}(r)

function promote_rule(::Type{StepRange{T1a,T1b}}, ::Type{StepRange{T2a,T2b}}) where {T1a,T1b,T2a,T2b}
    Tb = promote_type(T1b, T2b)
    # el_same only operates on array element type, so just promote second type parameter
    el_same(promote_type(T1a, T2a), StepRange{T1a,Tb}, StepRange{T2a,Tb})
end
StepRange{T1,T2}(r::StepRange{T1,T2}) where {T1,T2} = r
StepRange{T}(r::StepRange{T}) where {T} = r
StepRange(r::StepRange) = r

promote_rule(a::Type{StepRange{T1a,T1b}}, ::Type{UR}) where {T1a,T1b,UR<:AbstractUnitRange} =
    promote_rule(a, StepRange{eltype(UR), eltype(UR)})
StepRange{T1,T2}(r::AbstractRange) where {T1,T2} =
    StepRange{T1,T2}(convert(T1, first(r)), convert(T2, step(r)), convert(T1, last(r)))
StepRange(r::OrdinalRange{T,S}) where {T,S} = StepRange{T,S}(first(r), step(r), last(r))
StepRange{T}(r::OrdinalRange{<:Any,S}) where {T,S} = StepRange{T,S}(first(r), step(r), last(r))
(StepRange{T1,T2} where T1)(r::AbstractRange) where {T2} = StepRange{eltype(r),T2}(r)
StepRange(r::StepRangeLen) = StepRange{eltype(r)}(r)
StepRange{T}(r::StepRangeLen{<:Any,<:Any,S}) where {T,S} = StepRange{T,S}(r)

function promote_rule(::Type{StepRangeLen{T1,R1,S1,L1}},::Type{StepRangeLen{T2,R2,S2,L2}}) where {T1,T2,R1,R2,S1,S2,L1,L2}
    R, S, L = promote_type(R1, R2), promote_type(S1, S2), promote_type(L1, L2)
    el_same(promote_type(T1, T2), StepRangeLen{T1,R,S,L}, StepRangeLen{T2,R,S,L})
end
StepRangeLen{T,R,S,L}(r::StepRangeLen{T,R,S,L}) where {T,R,S,L} = r
StepRangeLen{T,R,S,L}(r::StepRangeLen) where {T,R,S,L} =
    StepRangeLen{T,R,S,L}(convert(R, r.ref), convert(S, r.step), convert(L, r.len), convert(L, r.offset))
StepRangeLen{T}(r::StepRangeLen) where {T} =
    StepRangeLen(convert(T, r.ref), convert(T, r.step), r.len, r.offset)

promote_rule(a::Type{StepRangeLen{T,R,S,L}}, ::Type{OR}) where {T,R,S,L,OR<:AbstractRange} =
    promote_rule(a, StepRangeLen{eltype(OR), eltype(OR), eltype(OR), Int})
StepRangeLen{T,R,S,L}(r::AbstractRange) where {T,R,S,L} =
    StepRangeLen{T,R,S,L}(R(first(r)), S(step(r)), length(r))
StepRangeLen{T}(r::AbstractRange) where {T} =
    StepRangeLen(T(first(r)), T(step(r)), length(r))
StepRangeLen(r::AbstractRange) = StepRangeLen{eltype(r)}(r)

function promote_rule(a::Type{LinRange{T1,L1}}, b::Type{LinRange{T2,L2}}) where {T1,T2,L1,L2}
    L = promote_type(L1, L2)
    el_same(promote_type(T1, T2), LinRange{T1,L}, LinRange{T2,L})
end
LinRange{T,L}(r::LinRange{T,L}) where {T,L} = r
LinRange{T,L}(r::AbstractRange) where {T,L} = LinRange{T,L}(first(r), last(r), length(r))
LinRange{T}(r::AbstractRange) where {T} = LinRange{T,typeof(length(r))}(first(r), last(r), length(r))
LinRange(r::AbstractRange{T}) where {T} = LinRange{T}(r)

promote_rule(a::Type{LinRange{T,L}}, ::Type{OR}) where {T,L,OR<:OrdinalRange} =
    promote_rule(a, LinRange{eltype(OR),L})

promote_rule(::Type{LinRange{A,L}}, b::Type{StepRangeLen{T2,R2,S2,L2}}) where {A,L,T2,R2,S2,L2} =
    promote_rule(StepRangeLen{A,A,A,L}, b)

## concatenation ##

function vcat(rs::AbstractRange{T}...) where T
    n::Int = 0
    for ra in rs
        n += length(ra)
    end
    a = Vector{T}(undef, n)
    i = 1
    for ra in rs, x in ra
        @inbounds a[i] = x
        i += 1
    end
    return a
end

# This method differs from that for AbstractArrays as it
# use iteration instead of indexing. This works even if certain
# non-standard ranges don't support indexing.
# See https://github.com/JuliaLang/julia/pull/27302
# Similarly, collect(r::AbstractRange) uses iteration
function Array{T,1}(r::AbstractRange{T}) where {T}
    a = Vector{T}(undef, length(r))
    i = 1
    for x in r
        @inbounds a[i] = x
        i += 1
    end
    return a
end
collect(r::AbstractRange) = Array(r)

_reverse(r::OrdinalRange, ::Colon) = (:)(last(r), negate(step(r)), first(r))
function _reverse(r::StepRangeLen, ::Colon)
    # If `r` is empty, `length(r) - r.offset + 1 will be nonpositive hence
    # invalid. As `reverse(r)` is also empty, any offset would work so we keep
    # `r.offset`
    offset = isempty(r) ? r.offset : length(r)-r.offset+1
    return typeof(r)(r.ref, negate(r.step), length(r), offset)
end
_reverse(r::LinRange{T}, ::Colon) where {T} = typeof(r)(r.stop, r.start, length(r))

## sorting ##

issorted(r::AbstractUnitRange) = true
issorted(r::AbstractRange) = length(r) <= 1 || step(r) >= zero(step(r))

sort(r::AbstractUnitRange) = r
sort!(r::AbstractUnitRange) = r

sort(r::AbstractRange) = issorted(r) ? r : reverse(r)

sortperm(r::AbstractUnitRange) = eachindex(r)
sortperm(r::AbstractRange) = issorted(r) ? (firstindex(r):1:lastindex(r)) : (lastindex(r):-1:firstindex(r))

function sum(r::AbstractRange{<:Real})
    l = length(r)
    # note that a little care is required to avoid overflow in l*(l-1)/2
    return l * first(r) + (iseven(l) ? (step(r) * (l-1)) * (l>>1)
                                     : (step(r) * l) * ((l-1)>>1))
end

function _in_range(x, r::AbstractRange)
    isempty(r) && return false
    f, l = first(r), last(r)
    # check for NaN, Inf, and large x that may overflow in the next calculation
    f <= x <= l || l <= x <= f || return false
    iszero(step(r)) && return true
    n = round(Integer, (x - f) / step(r)) + 1
    n >= 1 && n <= length(r) && r[n] == x
end
in(x::Real, r::AbstractRange{<:Real}) = _in_range(x, r)
# This method needs to be defined separately since -(::T, ::T) can be implemented
# even if -(::T, ::Real) is not
in(x::T, r::AbstractRange{T}) where {T} = _in_range(x, r)

in(x::Integer, r::AbstractUnitRange{<:Integer}) = (first(r) <= x) & (x <= last(r))

in(x::Real, r::AbstractRange{T}) where {T<:Integer} =
    isinteger(x) && !isempty(r) &&
    (iszero(step(r)) ? x == first(r) : (x >= minimum(r) && x <= maximum(r) &&
        (mod(convert(T,x),step(r))-mod(first(r),step(r)) == 0)))
in(x::AbstractChar, r::AbstractRange{<:AbstractChar}) =
    !isempty(r) &&
    (iszero(step(r)) ? x == first(r) : (x >= minimum(r) && x <= maximum(r) &&
        (mod(Int(x) - Int(first(r)), step(r)) == 0)))

# Addition/subtraction of ranges

function _define_range_op(@nospecialize f)
    @eval begin
        function $f(r1::OrdinalRange, r2::OrdinalRange)
            r1l = length(r1)
            (r1l == length(r2) ||
             throw(DimensionMismatch("argument dimensions must match: length of r1 is $r1l, length of r2 is $(length(r2))")))
            StepRangeLen($f(first(r1), first(r2)), $f(step(r1), step(r2)), r1l)
        end

        function $f(r1::LinRange{T}, r2::LinRange{T}) where T
            len = r1.len
            (len == r2.len ||
             throw(DimensionMismatch("argument dimensions must match: length of r1 is $len, length of r2 is $(r2.len)")))
            LinRange{T}(convert(T, $f(first(r1), first(r2))),
                        convert(T, $f(last(r1), last(r2))), len)
        end

        $f(r1::Union{StepRangeLen, OrdinalRange, LinRange},
           r2::Union{StepRangeLen, OrdinalRange, LinRange}) =
               $f(promote(r1, r2)...)
    end
end
_define_range_op(:+)
_define_range_op(:-)

function +(r1::StepRangeLen{T,S}, r2::StepRangeLen{T,S}) where {T,S}
    len = length(r1)
    (len == length(r2) ||
     throw(DimensionMismatch("argument dimensions must match: length of r1 is $len, length of r2 is $(length(r2))")))
    StepRangeLen(first(r1)+first(r2), step(r1)+step(r2), len)
end

-(r1::StepRangeLen, r2::StepRangeLen) = +(r1, -r2)

# Modular arithmetic on ranges

"""
    mod(x::Integer, r::AbstractUnitRange)

Find `y` in the range `r` such that `x` ≡ `y` (mod `n`), where `n = length(r)`,
i.e. `y = mod(x - first(r), n) + first(r)`.

See also [`mod1`](@ref).

# Examples
```jldoctest
julia> mod(0, Base.OneTo(3))  # mod1(0, 3)
3

julia> mod(3, 0:2)  # mod(3, 3)
0
```

!!! compat "Julia 1.3"
     This method requires at least Julia 1.3.
"""
mod(i::Integer, r::OneTo) = mod1(i, last(r))
mod(i::Integer, r::AbstractUnitRange{<:Integer}) = mod(i-first(r), length(r)) + first(r)


"""
    logrange(start, stop, length)
    logrange(start, stop; length)

Construct a specialized array whose elements are spaced logarithmically
between the given endpoints. That is, the ratio of successive elements is
a constant, calculated from the length.

This is similar to `geomspace` in Python. Unlike `PowerRange` in Mathematica,
you specify the number of elements not the ratio.
Unlike `logspace` in Python and Matlab, the `start` and `stop` arguments are
always the first and last elements of the result, not powers applied to some base.

# Examples
```jldoctest
julia> logrange(10, 4000, length=3)
3-element Base.LogRange{Float64, Base.TwicePrecision{Float64}}:
 10.0, 200.0, 4000.0

julia> ans[2] ≈ sqrt(10 * 4000)  # middle element is the geometric mean
true

julia> range(10, 40, length=3)[2] ≈ (10 + 40)/2  # arithmetic mean
true

julia> logrange(1f0, 32f0, 11)
11-element Base.LogRange{Float32, Float64}:
 1.0, 1.41421, 2.0, 2.82843, 4.0, 5.65685, 8.0, 11.3137, 16.0, 22.6274, 32.0

julia> logrange(1, 1000, length=4) ≈ 10 .^ (0:3)
true
```

See the [`LogRange`](@ref Base.LogRange) type for further details.

See also [`range`](@ref) for linearly spaced points.

!!! compat "Julia 1.11"
    This function requires at least Julia 1.11.
"""
logrange(start::Real, stop::Real, length::Integer) = LogRange(start, stop, Int(length))
logrange(start::Real, stop::Real; length::Integer) = logrange(start, stop, length)


"""
    LogRange{T}(start, stop, len) <: AbstractVector{T}

A range whose elements are spaced logarithmically between `start` and `stop`,
with spacing controlled by `len`. Returned by [`logrange`](@ref).

Like [`LinRange`](@ref), the first and last elements will be exactly those
provided, but intermediate values may have small floating-point errors.
These are calculated using the logs of the endpoints, which are
stored on construction, often in higher precision than `T`.

# Examples
```jldoctest
julia> logrange(1, 4, length=5)
5-element Base.LogRange{Float64, Base.TwicePrecision{Float64}}:
 1.0, 1.41421, 2.0, 2.82843, 4.0

julia> Base.LogRange{Float16}(1, 4, 5)
5-element Base.LogRange{Float16, Float64}:
 1.0, 1.414, 2.0, 2.828, 4.0

julia> logrange(1e-310, 1e-300, 11)[1:2:end]
6-element Vector{Float64}:
 1.0e-310
 9.999999999999974e-309
 9.999999999999981e-307
 9.999999999999988e-305
 9.999999999999994e-303
 1.0e-300

julia> prevfloat(1e-308, 5) == ans[2]
true
```

Note that integer eltype `T` is not allowed.
Use for instance `round.(Int, xs)`, or explicit powers of some integer base:

```jldoctest
julia> xs = logrange(1, 512, 4)
4-element Base.LogRange{Float64, Base.TwicePrecision{Float64}}:
 1.0, 8.0, 64.0, 512.0

julia> 2 .^ (0:3:9) |> println
[1, 8, 64, 512]
```

!!! compat "Julia 1.11"
    This type requires at least Julia 1.11.
"""
struct LogRange{T<:Real,X} <: AbstractArray{T,1}
    start::T
    stop::T
    len::Int
    extra::Tuple{X,X}
    function LogRange{T}(start::T, stop::T, len::Int) where {T<:Real}
        if T <: Integer
            # LogRange{Int}(1, 512, 4) produces InexactError: Int64(7.999999999999998)
            throw(ArgumentError("LogRange{T} does not support integer types"))
        end
        if iszero(start) || iszero(stop)
            throw(DomainError((start, stop),
                "LogRange cannot start or stop at zero"))
        elseif start < 0 || stop < 0
            # log would throw, but _log_twice64_unchecked does not
            throw(DomainError((start, stop),
                "LogRange does not accept negative numbers"))
        elseif !isfinite(start) || !isfinite(stop)
            throw(DomainError((start, stop),
                "LogRange is only defined for finite start & stop"))
        elseif len < 0
            throw(ArgumentError(LazyString(
                "LogRange(", start, ", ", stop, ", ", len, "): can't have negative length")))
        elseif len == 1 && start != stop
            throw(ArgumentError(LazyString(
                "LogRange(", start, ", ", stop, ", ", len, "): endpoints differ, while length is 1")))
        end
        ex = _logrange_extra(start, stop, len)
        new{T,typeof(ex[1])}(start, stop, len, ex)
    end
end

function LogRange{T}(start::Real, stop::Real, len::Integer) where {T}
    LogRange{T}(convert(T, start), convert(T, stop), convert(Int, len))
end
function LogRange(start::Real, stop::Real, len::Integer)
    T = float(promote_type(typeof(start), typeof(stop)))
    LogRange{T}(convert(T, start), convert(T, stop), convert(Int, len))
end

size(r::LogRange) = (r.len,)
length(r::LogRange) = r.len

first(r::LogRange) = r.start
last(r::LogRange) = r.stop

function _logrange_extra(a::Real, b::Real, len::Int)
    loga = log(1.0 * a)  # widen to at least Float64
    logb = log(1.0 * b)
    (loga/(len-1), logb/(len-1))
end
function _logrange_extra(a::Float64, b::Float64, len::Int)
    loga = _log_twice64_unchecked(a)
    logb = _log_twice64_unchecked(b)
    # The reason not to do linear interpolation on log(a)..log(b) in `getindex` is
    # that division of TwicePrecision is quite slow, so do it once on construction:
    (loga/(len-1), logb/(len-1))
end

function getindex(r::LogRange{T}, i::Int) where {T}
    @inline
    @boundscheck checkbounds(r, i)
    i == 1 && return r.start
    i == r.len && return r.stop
    # Main path uses Math.exp_impl for TwicePrecision, but is not perfectly
    # accurate, hence the special cases for endpoints above.
    logx = (r.len-i) * r.extra[1] + (i-1) * r.extra[2]
    x = _exp_allowing_twice64(logx)
    return T(x)
end

function show(io::IO, r::LogRange{T}) where {T}
    print(io, "LogRange{", T, "}(")
    ioc = IOContext(io, :typeinfo => T)
    show(ioc, first(r))
    print(io, ", ")
    show(ioc, last(r))
    print(io, ", ")
    show(io, length(r))
    print(io, ')')
end

# Implementation detail of @world
# The rest of this is defined in essentials.jl, but UnitRange is not available
function _resolve_in_world(worlds::UnitRange, gr::GlobalRef)
    # Validate that this binding's reference covers the entire world range
    bpart = lookup_binding_partition(UInt(first(worlds)), gr)
    if bpart.max_world < last(worlds)
        error("Binding does not cover the full world range")
    end
    _resolve_in_world(UInt(last(worlds)), gr)
end
