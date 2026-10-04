"""
    inc(x)

Return `x` one unit up, wrapping around at `typemax` like any integer `+`. See also [`dec`](@ref).
"""
@inline inc(x) = x + oneunit(x)

"""
    dec(x)

Return `x` one unit down, wrapping around at `typemin` like any integer `-`. See also [`inc`](@ref).
"""
@inline dec(x) = x - oneunit(x)

"""
    successor(x::T)::Union{Nothing, T}

Return the neighbor above `x`, or `nothing` if `x`'s type holds no larger value.

Defining this method is what makes `T` discrete, so define [`predecessor`](@ref) along with it. Both owe the same contract:

- The neighbor has the type of `x`.
- `nothing` says the type holds no further value.
- No value of `T` lies between `x` and its neighbor
- `predecessor(x) < x < successor(x)`.
- `predecessor(successor(x)) == x` wherever both exist (=not `nothing`).

`T` itself needs `isless`, and `==`, too, unless `===` already compares its values.
"""
(successor(x::T)::Union{Nothing, T}) where T <: Integer = Base.hastypemax(T) && x == typemax(x) ? nothing : inc(x)
successor(x::Union{NegativeInfinity, PositiveInfinity}) = x

"""
    predecessor(x::T)::Union{Nothing, T}

Return the neighbor below `x`, or `nothing` if `x`'s type holds no smaller value.

Every type with a [`successor`](@ref) needs this method too, under the contract stated there.
"""
(predecessor(x::T)::Union{Nothing, T}) where T <: Integer = Base.hastypemax(T) && x == typemin(x) ? nothing : dec(x)
predecessor(x::Union{NegativeInfinity, PositiveInfinity}) = x

"""
    isdiscrete(T::Type)

Determine whether `T` is interpreted as having neighboring values.

A type is discrete once it has a [`successor`](@ref) method, so per default `Int` is discrete and `Float64` is not.
Define `isdiscrete` yourself only to overrule that, as in
`UncertainIntervals.isdiscrete(::Type{Float64}) = false` for a type whose neighbors serve
another purpose.
"""
isdiscrete(::Type{T}) where T = hasmethod(successor, Tuple{T})
isdiscrete(::Type{Union{}}) = "`Union{}` has no values that could be neighbors" |> ArgumentError |> throw

"""
    respell(::Type{T}, v, from::Openness, to::Openness)

Return the limit `v` of an interval over `T` spelled with the openness `to` in place of `from`, or `nothing` where no such limit exists.

The closed spelling of an open limit uses one value inwards and the open spelling of a closed one use one value outwards, so only a discrete element type spells a limit both ways. An uncertain bound has no single value to move, so it keeps the openness it has.

# Examples
```jldoctest
julia> using UncertainIntervals: respell, LeftOpen, LeftClosed

julia> respell(Int, 3, LeftOpen(), LeftClosed())  # `(3` and `[4` are the same limit
4

julia> respell(Int, 3, LeftClosed(), LeftOpen())  # `[3` and `(2` are the same limit
2
```
"""
@inline respell(::Type{T}, v, from::LeftOpenness, to::LeftOpenness) where T =
    from == to ? v : isdiscrete(T) ? (isclosed(to) ? successor(v) : predecessor(v)) : nothing
@inline respell(::Type{T}, v, from::RightOpenness, to::RightOpenness) where T =
    from == to ? v : isdiscrete(T) ? (isclosed(to) ? predecessor(v) : successor(v)) : nothing
@inline respell(::Type, v::AInterval, from::LeftOpenness, to::LeftOpenness) = from == to ? v : nothing
@inline respell(::Type, v::AInterval, from::RightOpenness, to::RightOpenness) = from == to ? v : nothing

"""
    closed(T, v, o...)

Return the closed limit equivalent to `v` with the opennesses `o`, or `nothing` where `T` has no such value.

Each open `o` moves `v` one step inwards. Pass the openness of the endpoint's uncertainty first, then the interval's, so `((3, 4), 9]` over `Int` starts at `closed(Int, 3, LeftOpen(), LeftOpen()) == 5`.
"""
@inline closed(::Type{T}, v, o::LeftOpenness) where T = respell(T, v, o, LeftClosed())
@inline closed(::Type{T}, v, o::RightOpenness) where T = respell(T, v, o, RightClosed())
@inline closed(::Type{T}, v, o::Openness, p::Openness) where T = closed(T, @∃(closed(T, v, o)), p)
