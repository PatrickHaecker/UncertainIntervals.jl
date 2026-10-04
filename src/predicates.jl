# Unlike `>` and `>=`, these also hold for values that do not compare at all, such as `NaN`.
@inline ≰(a, b) = !(a <= b)
@inline ≮(a, b) = !(a < b)

"""
    isemptybound(b)::Bool

Determine whether the bound `b` is empty, as `(3, 3)` is. Like `isempty`, except that a plain value is never empty, whatever `isempty` says about it.
"""
@inline isemptybound(_) = false
@inline isemptybound(b::InnerInterval) = isempty(b)

"""
    isempty(x::AInterval)

Determine whether the interval contains no value.

Return `true` if `x` is certainly empty, `false` if it is certainly nonempty, and `missing` otherwise.
"""
@inline Base.isempty(x::AInterval) = isempty_clamped(clamp_infinities(x))

@inline function isempty_clamped(x::AInterval{T})::Union{Bool, Missing} where T
    if isdiscrete(T)
        # Move every open limit inwards to compare closed limits.
        ll, rr = @∃ widest_ordinals(x) true
        @⏎⊤ ll ≰ rr
        # A narrowest limit beyond `T` leaves `x` possibly empty, and certainly empty if a bound is empty.
        lr, rl = @∃ narrowest_ordinals(x) (isemptybound(x.left) || isemptybound(x.right) ? true : missing)
        # An empty bound leaves `x` certainly empty.
        @⏎⊤ ll ≰ lr || rl ≰ rr
        return lr <= rl ? false : missing
    else
        (; ₍, l, r, ₎) = x
        # A single shared endpoint is a member only where both sides of `x` are closed.
        ⪯ʷ = isclosed(l.₍) && isclosed(₍) && isclosed(₎) && isclosed(r.₎) ? (<=) : (<)
        ⪯ⁿ = isopen(l.₎) || isclosed(₍) && isclosed(₎) || isopen(r.₍) ? (<=) : (<)
        certainly_empty = isemptybound(x.left) || isemptybound(x.right) || !(l.l ⪯ʷ r.r)
        certainly_nonempty = l.r ⪯ⁿ r.l
        known = certainly_empty || certainly_nonempty
        return known ? certainly_empty : missing
    end
end

@inline function Base.isempty(x::InnerInterval{T})::Bool where T
    (; left, ₍, right, ₎) = clamp_infinities(x)
    isclosed(₍) && isclosed(₎) && return left ≰ right
    isdiscrete(T) && isopen(₍) && isopen(₎) && return step_up(left) ≮ right
    return left ≮ right
end

"""
    certain_endpoint(b)

Return the only value the bound `b` allows for its endpoint, or `missing` if it allows none or several.

The discrete intervals `(2, 4)` and `(2, 3]` contain only `3`. A dense one needs `[v, v]` to contain a single value.
"""
@inline certain_endpoint(b) = b
@inline function certain_endpoint(b::AInterval{T}) where T
    (; l, ₍, r, ₎) = limits(b)
    lo, hi = closed(T, l, ₍), closed(T, r, ₎)
    return !isnothing(lo) && lo == hi ? lo : missing
end

# Test for member equality.
@inline Base.:(==)(x::AInterval{T}, y::AInterval{T}) where T = equal_clamped(clamp_infinities(x), clamp_infinities(y))

@inline function equal_clamped(x::AInterval{T}, y::AInterval{T})::Union{Bool, Missing} where T
    empty_x, empty_y = isempty(x), isempty(y)
    (ismissing(empty_x) || ismissing(empty_y)) && return missing
    empty_x && return empty_y # every empty interval holds the same nothing
    empty_y && return false

    return if isdiscrete(T)
        # Ordinals compare like the closed limits, and for a machine integer they exist even where those do not, so the fallback folds away.
        xll, xrr = @∃ widest_ordinals(x) missing
        xlr, xrl = @∃ narrowest_ordinals(x) missing
        yll, yrr = @∃ widest_ordinals(y) missing
        ylr, yrl = @∃ narrowest_ordinals(y) missing
        # Equality can't be determined if any endpoint is uncertain.
        (xll == xlr) & (xrl == xrr) & (yll == ylr) & (yrl == yrr) || return missing
        # The intervals are equal if their canonical minimum and maximum agree.
        (xll == yll) & (xrr == yrr)
    else
        xl = @■ certain_endpoint(x.left)
        xr = @■ certain_endpoint(x.right)
        yl = @■ certain_endpoint(y.left)
        yr = @■ certain_endpoint(y.right)
        # `&` keeps machine floats branch-free where not inlined, `&&` skips the remaining comparisons for expensive types.
        T <: Base.IEEEFloat ?
            (x.₍ == y.₍) & (x.₎ == y.₎) & (xl == yl) & (xr == yr) :
            x.₍ == y.₍ && x.₎ == y.₎ && xl == yl && xr == yr
    end
end

@inline function equal_clamped(x::InnerInterval{T}, y::InnerInterval{T})::Bool where T
    # Branchless, as data-dependent branches mispredict.
    ex, ey = isempty(x), isempty(y)
    same = isdiscrete(T) ?
        (left_ordinal(x) == left_ordinal(y)) & (right_ordinal(x) == right_ordinal(y)) :
        (x.₍ == y.₍) & (x.₎ == y.₎) & (x.left == y.left) & (x.right == y.right)
    # Where the first term holds, `ex` and `ey` agree, so `ex | same` works without `ey`.
    return (ex == ey) & (ex | same)
end

"""
    in(v, x::AInterval)

Determine whether `v` is a member of `x`.

The answer is `true` or `false` where every endpoint `x` can take agrees on it, and `missing` where they differ, so `5 in i"[(1, 9), 20]"` is `missing` while `9 in i"[(1, 9), 20]"` is `true`. An unknown `v`, that is `missing`, is only ruled out by a certainly empty `x`.
"""
@inline Base.in(v, x::AInterval) = in_clamped(v, clamp_infinities(x))

@inline function in_clamped(v, x::AInterval{T})::Union{Bool, Missing} where T
    if isdiscrete(T)
        # Move every open limit inwards to compare closed limits.
        ll, rr = @∃ widest_ordinals(x) false
        # `!<=` rather than `>`, as a value that compares with nothing is no member either.
        (ll <= v && v <= rr) || return false
        lr, rl = @∃ narrowest_ordinals(x) (isemptybound(x.left) || isemptybound(x.right) ? false : missing)
        # An empty bound certainly keeps `v` out.
        (ll <= lr && rl <= rr) || return false
        return lr <= v && v <= rl ? true : missing
    else
        (; ₍, l, r, ₎) = x
        (isemptybound(x.left) || isemptybound(x.right)) && return false
        # The widest limits hold every possible member, the narrowest ones only the certain members.
        ⪰₍ʷ = isclosed(l.₍) && isclosed(₍) ? (>=) : (>)
        ⪯₎ʷ = isclosed(r.₎) && isclosed(₎) ? (<=) : (<)
        ⪰₍ⁿ = isopen(l.₎) || isclosed(₍) ? (>=) : (>)
        ⪯₎ⁿ = isopen(r.₍) || isclosed(₎) ? (<=) : (<)
        v ⪰₍ʷ l.l && v ⪯₎ʷ r.r || return false
        return v ⪰₍ⁿ l.r && v ⪯₎ⁿ r.l ? true : missing
    end
end

# Branchless where every endpoint is certain. A discrete limit only moves inwards for a value of its own type.
@inline function Base.in(v, x::InnerInterval{T})::Bool where T
    v isa T || !isdiscrete(T) || return @invoke in(v, x::AInterval)
    (; left, ₍, right, ₎) = clamp_infinities(x)
    ⪰₍ = isclosed(₍) ? (>=) : (>)
    ⪯₎ = isclosed(₎) ? (<=) : (<)
    return (v ⪰₍ left) & (v ⪯₎ right)
end

# The second method settles the ambiguity with `in(v, ::InnerInterval)`.
@inline Base.in(::Missing, x::AInterval) = isempty(x) === true ? false : missing
@inline Base.in(::Missing, x::InnerInterval) = isempty(x) ? false : missing

"""
    certainly_within(x::AInterval, y::AInterval)::Bool

Determine whether `x ⊆ y` holds whichever endpoints `x` and `y` take, that is whether the widest limits of `x` lie within the narrowest limits of `y`.

Neither `x` nor `y` may be certainly empty. `[7, 3]` is certainly empty, `[[1, 9], 5]` is not, as only some of its left endpoints leave it empty.
"""
@inline function certainly_within(x::AInterval{T}, y::AInterval{T})::Bool where T
    if isdiscrete(T)
        xll, xrr = @∃ widest_ordinals(x) true
        ylr, yrl = @∃ narrowest_ordinals(y) false
        return xll >= ylr && xrr <= yrl
    else
        # A shared limit belongs to `y` wherever `y` is closed at it or `x` never reaches it.
        ⪰₍ = isopen(y.l.₎) || isclosed(y.₍) || isopen(x.l.₍) || isopen(x.₍) ? (>=) : (>)
        ⪯₎ = isopen(y.r.₍) || isclosed(y.₎) || isopen(x.r.₎) || isopen(x.₎) ? (<=) : (<)
        return x.l.l ⪰₍ y.l.r && x.r.r ⪯₎ y.r.l
    end
end

"""
    possibly_within(x::AInterval, y::AInterval)::Bool

Determine whether `x ⊆ y` holds for some endpoints `x` and `y` can take, that is whether the narrowest limits of `x` lie within the widest limits of `y`.

`x` must be certainly non-empty, as `[1, 9]` is and `[[1, 9], 5]` is not, and `y` must not be certainly empty, see [`certainly_within`](@ref).
"""
@inline function possibly_within(x::AInterval{T}, y::AInterval{T})::Bool where T
    if isdiscrete(T)
        xlr, xrl = @∃ narrowest_ordinals(x) true
        yll, yrr = @∃ widest_ordinals(y) false
        return xlr >= yll && xrl <= yrr
    end
    # A limit can be shared at all only where both endpoints attain it.
    ⪰₍ = isclosed(x.l.₎) && isclosed(y.l.₍) && (isclosed(y.₍) || isopen(x.₍)) ? (>=) : (>)
    ⪯₎ = isclosed(x.r.₍) && isclosed(y.r.₎) && (isclosed(y.₎) || isopen(x.₎)) ? (<=) : (<)
    return x.l.r ⪰₍ y.l.l && x.r.l ⪯₎ y.r.r
end

"""
    issubset(x::AInterval, y::AInterval)

Determine whether every member of `x` is a member of `y`.

Return `missing` where the possible endpoints disagree. So `i"[1, 2]" ⊆ i"[[1, 3], 7]"` is `missing`, but `i"[1, 2]" ⊆ i"[(1, 3), 7]"` is `false`, as an integer endpoint in `(1, 3)` can only be `2`.

An empty interval is a subset of every interval, and only an empty one is a subset of an empty interval.
"""
@inline Base.issubset(x::AInterval{T}, y::AInterval{T}) where T = issubset_clamped(clamp_infinities(x), clamp_infinities(y))

@inline function issubset_clamped(x::AInterval{T}, y::AInterval{T})::Union{Bool, Missing} where T
    empty_x = isempty(x)
    empty_x === true && return true # a certainly empty `x` asks nothing of `y`
    # A certainly empty `y` has room for nothing, and an empty bound turns the limits around that the readings below rely on.
    isempty(y) === true && return empty_x === false ? false : missing

    certainly_within(x, y) && return true
    return empty_x === false && !possibly_within(x, y) ? false : missing
end

# Branchless where every endpoint is certain. The closed limits are only reliable where both intervals hold a value.
@inline function issubset_clamped(x::InnerInterval{T}, y::InnerInterval{T})::Bool where T
    within = if isdiscrete(T)
        (left_ordinal(x) >= left_ordinal(y)) & (right_ordinal(x) <= right_ordinal(y))
    else
        ⪰₍ = isopen(x.₍) | isclosed(y.₍) ? (>=) : (>)
        ⪯₎ = isopen(x.₎) | isclosed(y.₎) ? (<=) : (<)
        (x.left ⪰₍ y.left) & (x.right ⪯₎ y.right)
    end
    return isempty(x) | !isempty(y) & within
end
