# An ordinal is a value that sorts exactly like a closed limit and serves only for comparing. It need not be of the element type, so it exists even where the closed limit would step beyond that type.

"""
    widen_signed(x)

Return `x` in the next wider signed type, so a step either way of it neither wraps around nor drops below an unsigned zero.
"""
@inline widen_signed(x) = signed(widen(x))

"""
    widens(T::Type)

Determine whether a step of the machine integer type `T` is cheaper in the next wider signed type than as [`Shifted`](@ref).

That holds below 32 bits, as measured on x86 with AVX2. Loops over many intervals vectorize with one interval per lane of a 256-bit register. 64-bit lanes are available, but hold half as many values, need a sign extension first, and compare in three cycles at one per cycle (`vpcmpgtq`), where 32-bit lanes compare in one cycle at two per cycle. `Shifted` keeps the lanes at 32 bits for a few cheap extra operations.
"""
@inline widens(::Type{T}) where T = sizeof(T) < 4

@inline inward(w, o::LeftOpenness) = isopen(o) ? inc(w) : w
@inline inward(w, o::RightOpenness) = isopen(o) ? dec(w) : w

@inline offset(o::LeftOpenness) = isopen(o) ? 1 : 0
@inline offset(o::RightOpenness) = isopen(o) ? -1 : 0

"""
    Shifted{T}(v, s)

The value `v` shifted by `s` steps, compared like `v + s` without computing it, so no step runs out of the values of `T`.

In an [`Interval`](@ref), a limit steps at most twice, once where the uncertainty of the endpoint is open and once where the interval is open, so `s` lies in `-2:2`. In `((1, 3), 7]` over `Int`, the open uncertainty `(1, 3)` makes the lowest left endpoint `2`, and the open interval makes its lowest member `3`, `1` stepped twice.
"""
struct Shifted{T <: Base.BitInteger}
    v::T
    s::Int
end

# `a <= b` means `a.v - b.v <= b.s - a.s`. The shifts are small, but `a.v - b.v` can wrap around in `T`.
# Read as unsigned, the wrapped difference is still the true one wherever that is not negative, and `a.v <= b.v` tells which case holds.
# So a comparison gives the sign and the wrapped difference the size, without widening `T`.
@inline function Base.:(<=)(a::Shifted{T}, b::Shifted{T}) where T <: Base.BitInteger
    d = b.s - a.s
    if d >= 0 # branch-free for `.s` only depending on type parameters like `Openness`
        return (a.v <= b.v) | ((a.v - b.v) % unsigned(T) <= d)
    else
        return (a.v < b.v) & ((b.v - a.v) % unsigned(T) >= -d)
    end
end
# `a == b` means `a.v - b.v == d`. Wrapped in `T`, a true difference of `d ± 2^N` matches as well, but has another sign than `d`.
@inline function Base.:(==)(a::Shifted{T}, b::Shifted{T}) where T <: Base.BitInteger
    d = b.s - a.s
    return ((a.v - b.v) % unsigned(T) == d % unsigned(T)) & (cmp(a.v, b.v) == sign(d))
end
@inline Base.:(<)(a::Shifted{T}, b::Shifted{T}) where T <: Base.BitInteger = !(b <= a)
for op in (:(==), :(<=), :(<))
    @eval @inline Base.$op(a::Shifted{T}, v::T) where T <: Base.BitInteger = $op(a, Shifted{T}(v, 0))
    @eval @inline Base.$op(v::T, a::Shifted{T}) where T <: Base.BitInteger = $op(Shifted{T}(v, 0), a)
end
@inline Base.:(<=)(a::Shifted, v::Real) = widen_signed(a.v) + a.s <= v
@inline Base.:(<=)(v::Real, a::Shifted) = v <= widen_signed(a.v) + a.s

"""
    closed_ordinal(T, v, o...)

Return an *ordinal* for the limit `v` with openness `o`: a value that sorts exactly like the closed limit `closed(T, v, o...)`, but need not be of type `T`. Return `nothing` only where `T` is no machine integer and the closed limit does not exist.

Sorting is all that `isempty`, `in` and `⊆` need, and for a machine integer an ordinal exists even where the closed limit does not:

```jldoctest
julia> using UncertainIntervals: closed, closed_ordinal, LeftOpen

julia> closed_ordinal(Int8, Int8(3), LeftOpen()) == Int8(4)  # `(3` is `[4`
true

julia> closed(Int8, typemax(Int8), LeftOpen())  # `nothing`, as `(127` has no closed limit in `Int8`

julia> closed_ordinal(Int8, typemax(Int8), LeftOpen()) > typemax(Int8)  # but its ordinal sorts above every `Int8`
true
```

An ordinal is no limit, though, and need not even be a number, so never store one in an interval. [`widens`](@ref) picks the representation for a machine integer.
"""
@inline closed_ordinal(::Type{T}, v, o::Openness...) where T =
    T <: Base.BitInteger ?
        widens(T) ? foldl(inward, o; init = widen_signed(v)) : Shifted{T}(v, sum(offset, o)) :
        closed(T, v, o...)

"""
    step_up(v)

Return a value that compares like [`successor(v)`](@ref successor), and where there is none, one that is no smaller than `v`.

The result is only fit for comparing, as a machine integer steps like in [`closed_ordinal`](@ref) instead of checking for its `typemax`. See also [`step_down`](@ref).
"""
@inline step_up(v) = v isa Base.BitInteger ? (widens(typeof(v)) ? inc(widen_signed(v)) : Shifted(v, 1)) : something(successor(v), v)

"""
    step_down(v)

Return a value that compares like [`predecessor(v)`](@ref predecessor), and where there is none, one that is no larger than `v`. See [`step_up`](@ref).
"""
@inline step_down(v) = v isa Base.BitInteger ? (widens(typeof(v)) ? dec(widen_signed(v)) : Shifted(v, -1)) : something(predecessor(v), v)

# Ordinals for the closed equivalents of a certain interval's limits, see `closed_ordinal` and `step_up`.
@inline left_ordinal(x) = isclosed(x.₍) ? x.left : step_up(x.left)
@inline right_ordinal(x) = isclosed(x.₎) ? x.right : step_down(x.right)

"""
    widest_ordinals(x::AInterval)::Union{Nothing, Tuple{Any, Any}}

Return `(ll, rr)`, ordinals for the lowest left and the highest right endpoint `x` can take, the limits of the widest interval it may be, or `nothing` where one of them has no ordinal. See [`closed_ordinal`](@ref).
"""
@inline function widest_ordinals(x::AInterval{T})::Union{Nothing, Tuple{Any, Any}} where T
    (; ₍, l, r, ₎) = x
    ll = @∃ closed_ordinal(T, l.l, l.₍, ₍)
    rr = @∃ closed_ordinal(T, r.r, r.₎, ₎)
    return ll, rr
end

"""
    narrowest_ordinals(x::AInterval)::Union{Nothing, Tuple{Any, Any}}

Return `(lr, rl)`, ordinals for the highest left and the lowest right endpoint `x` can take, the limits of the narrowest interval it may be, or `nothing` where one of them has no ordinal. See [`closed_ordinal`](@ref).
"""
@inline function narrowest_ordinals(x::AInterval{T})::Union{Nothing, Tuple{Any, Any}} where T
    (; ₍, l, r, ₎) = x
    lr = @∃ closed_ordinal(T, l.r, l.₎, ₍)
    rl = @∃ closed_ordinal(T, r.l, r.₍, ₎)
    return lr, rl
end
