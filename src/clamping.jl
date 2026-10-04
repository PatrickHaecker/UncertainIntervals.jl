"""
    linemin(::Type{T})::Union{Nothing, T}

Return the smallest member of `Line{T}()`, or `nothing` if it has none.

So `≤b` and `[linemin(T), b]` hold the same members. See also [`linemax`](@ref).
"""
@inline function linemin(::Type{T}) where T
    # This assumes that `hastypemin` would have the same result as `hastypemax`.
    Base.hastypemax(T) || return nothing
    m = typemin(T)
    return m == -∞ ? (isdiscrete(T) ? successor(m) : nothing) : m
end

"""
    linemax(::Type{T})::Union{Nothing, T}

Return the largest member of `Line{T}()`, or `nothing` if it has none.

So `≥a` and `[a, linemax(T)]` hold the same members. See also [`linemin`](@ref).
"""
@inline function linemax(::Type{T}) where T
    Base.hastypemax(T) || return nothing
    m = typemax(T)
    return m == +∞ ? (isdiscrete(T) ? predecessor(m) : nothing) : m
end

"""
    clamp_lower(T, v)

Return [`linemin(T)`](@ref linemin) in place of `v == -∞` where there is one, else `v`. [`unclamp_lower`](@ref) undoes it.
"""
@inline clamp_lower(::Type{T}, v) where T = v isa NegativeInfinity ? something(linemin(T), v) : v

"""
    clamp_upper(T, v)

Return [`linemax(T)`](@ref linemax) in place of `v == +∞` where there is one, else `v`. [`unclamp_upper`](@ref) undoes it.
"""
@inline clamp_upper(::Type{T}, v) where T = v isa PositiveInfinity ? something(linemax(T), v) : v

"""
    clamp_infinities(x)

Replace each infinity in `x` by the extreme value of its element type, if there is one, so `≥5` becomes `[5, typemax(Int)]`, while `≥big(5)` stays as it is, as `BigInt` has no largest value.

Once inlined, the new interval usually folds away.
"""
@inline clamp_infinities(v) = v
@inline function clamp_infinities(x::AInterval{T,Oₗ,Oᵣ,L,R}) where {T,Oₗ,Oᵣ,L,R}
    l, r = clamp_lower(T, clamp_infinities(x.left)), clamp_upper(T, clamp_infinities(x.right))
    Lₒ = L === NegativeInfinity && !(l isa NegativeInfinity) ? LeftClosed : Oₗ
    Rₒ = R === PositiveInfinity && !(r isa PositiveInfinity) ? RightClosed : Oᵣ
    return Interval{T, Lₒ, Rₒ, typeof(l), typeof(r)}(l, r)
end

"""
    unclamp_lower(T, v)

Return `-∞` where `v` is [`linemin(T)`](@ref linemin), else `v`, which undoes [`clamp_lower`](@ref).
"""
@inline function unclamp_lower(::Type{T}, v) where T
    e = linemin(T)
    return !isnothing(e) && v == e ? -∞ : v
end

"""
    unclamp_upper(T, v)

Return `+∞` where `v` is [`linemax(T)`](@ref linemax), else `v`, which undoes [`clamp_upper`](@ref).
"""
@inline function unclamp_upper(::Type{T}, v) where T
    e = linemax(T)
    return !isnothing(e) && v == e ? +∞ : v
end
