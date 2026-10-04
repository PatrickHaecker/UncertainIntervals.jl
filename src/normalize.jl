# A step out of the element type drops the one endpoint that reaches beyond it, and that endpoint leaves `x` empty. The extreme stands in for it wherever a kept endpoint leaves `x` empty as well, which keeps every possible member set.
@inline narrowest_upper(::Type{T}, v, rr) where T = isnothing(v) && Base.hastypemax(T) && rr < typemax(T) ? typemax(T) : v
@inline narrowest_lower(::Type{T}, v, ll) where T = isnothing(v) && Base.hastypemax(T) && typemin(T) < ll ? typemin(T) : v

"""
    canonical(x::AInterval)::Union{Nothing, Tuple{Tuple{Any, Any}, Tuple{Any, Any}}}

Return `((ll, lr), (rl, rr))`, the closed limits each endpoint of `x` can take, lowest first, or `nothing` where one of them has no closed equivalent in the element type.
"""
@inline function canonical(x::AInterval{T})::Union{Nothing, Tuple{Tuple{Any, Any}, Tuple{Any, Any}}} where T
    (; ₍, l, r, ₎) = x
    ll = @∃ closed(T, l.l, l.₍, ₍)
    rr = @∃ closed(T, r.r, r.₎, ₎)
    lr = @∃ narrowest_upper(T, closed(T, l.r, l.₎, ₍), rr)
    rl = @∃ narrowest_lower(T, closed(T, r.l, r.₍, ₎), ll)
    return (ll, lr), (rl, rr)
end

# A limit at infinity is the one that cannot be reached, so it is the one that stays open.
@inline canonical_left_openness(::NegativeInfinity) = LeftOpen
@inline canonical_left_openness(_) = LeftClosed
@inline canonical_right_openness(::PositiveInfinity) = RightOpen
@inline canonical_right_openness(_) = RightClosed

# A limit one step beyond the element type has no closed equivalent, which only `normalize` has to answer for.
@noinline no_canonical(x::AInterval{T}) where T = "`$x` has no canonical form, as a limit steps beyond `$T`" |> ArgumentError |> throw

"""
    canonical_bound(b, lo, hi)

Return the bound `b` rebuilt from its canonical limits as `[lo, hi]`, open only at an infinity, or as `lo` where `b` is a plain value.

An uncertain `b` stays an interval even where `lo == hi`, as in `[[3, 3], 7]`, so the result type follows from the type of `b` alone.
"""
@inline canonical_bound(::AInterval, lo, hi) = Interval{canonical_left_openness(lo), canonical_right_openness(hi)}(lo, hi)
@inline canonical_bound(_, lo, _) = lo

"""
    normalize(x::Interval)

Return the canonical form of `x`.

A discrete element type moves every open finite limit to the closed one a step inwards, so that `(3, 7)` becomes `[4, 6]` and `((1, 3), 7]` becomes `[[3, 3], 7]`. A limit at infinity stays open, and a dense element type leaves the interval as it is.

An empty interval has no canonical form, so an endpoint that empties `x` may be swapped for another one that empties it too, and a step beyond the element type stalls at the extreme. The call throws an `ArgumentError` where that swap is not available, as for `([1, typemax(Int)], typemax(Int)]`, and where the widest limit is the one that steps too far, as for `(typemax(Int), +∞)`.

Every bound keeps the shape it had, so the result type follows from the argument type. Use [`simplify`](@ref) to also drop an uncertainty that is fully resolved to a single value.
"""
@inline function normalize(x::Interval{T}) where T
    isdiscrete(T) || return x
    (ll, lr), (rl, rr) = @something canonical(x) no_canonical(x)
    left, right = canonical_bound(x.left, ll, lr), canonical_bound(x.right, rl, rr)
    return Interval{T, canonical_left_openness(left), canonical_right_openness(right), typeof(left), typeof(right)}(left, right)
end

# An endpoint that could take any value is the line over the element type.
@inline function simplified_bound(::Type{T}, lo, hi) where T
    l, h = unclamp_lower(T, lo), unclamp_upper(T, hi)
    return l isa NegativeInfinity && h isa PositiveInfinity ? Line{T}() :
        Interval{canonical_left_openness(l), canonical_right_openness(h)}(l, h)
end

"""
    simplify(x::Interval)

Return the canonical form of `x` with every uncertainty that is down to a single value dropped.

So `((1, 3), 7]` becomes `[3, 7]`, where [`normalize`](@ref) stops at `[[3, 3], 7]`. A limit at an extreme of the element type becomes the infinity beyond it, so `[5, typemax(Int)]` becomes `≥5`, which `normalize` leaves alone, and an endpoint that could take any value becomes `Line{T}()`.

Both take the same limits, but where none of them has a closed equivalent, as for `([1, typemax(Int)], typemax(Int)]`, this call returns `x` unchanged rather than throwing as `normalize` does.

Whether a bound collapses follows from the values rather than from the types, so the result type is not inferable and the call allocates. Reach for `normalize` wherever that matters.
"""
function simplify(x::Interval{T,Oₗ,Oᵣ}) where {T,Oₗ,Oᵣ}
    if isdiscrete(T)
        (ll, lr), (rl, rr) = @something canonical(x) return x
        l = ll == lr ? unclamp_lower(T, ll) : simplified_bound(T, ll, lr)
        r = rl == rr ? unclamp_upper(T, rr) : simplified_bound(T, rl, rr)
        Lₒ, Rₒ = LeftClosed, RightClosed
    else
        # Only a closed bound at the extreme reaches the infinity, as an open one leaves the extreme out.
        lo, hi = certain_endpoint(x.left), certain_endpoint(x.right)
        l = ismissing(lo) ? x.left : isclosed(Oₗ()) ? unclamp_lower(T, lo) : lo
        r = ismissing(hi) ? x.right : isclosed(Oᵣ()) ? unclamp_upper(T, hi) : hi
        Lₒ, Rₒ = Oₗ, Oᵣ
    end
    return Interval{T, l isa NegativeInfinity ? LeftOpen : Lₒ, r isa PositiveInfinity ? RightOpen : Rₒ, typeof(l), typeof(r)}(l, r)
end
