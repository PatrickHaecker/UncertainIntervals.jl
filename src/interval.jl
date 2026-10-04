# "An exact value. This is the default you know from regular bounds."
# struct Exact end
# "The minimum known value, so ̂B <(=) B for the estimated ̂B of the true bound B"
# struct Min end
# "The maximum known value, so ̂B >(=) B for the estimated ̂B of the true bound B"
# struct Max end
# const Determination = Union{Exact, Min, Max}

# Base.print(io::IO, ::Type{Exact}) = print(io, "")
# Base.print(io::IO, ::Type{Min}) = print(io, "≥")
# Base.print(io::IO, ::Type{Max}) = print(io, "≤")

# TODO: Strictly speaking the Determination and therefore the BoundType are now no longer needed: Whether we have an Exact, a Min or a Max bound follows from the field type. The following is using a curly brace if it does not matter whether the interval is open or closed:
# - T
# - (NegativeInfinity, T}
# - {T, PositiveInfinity)
# - {T, T}
# """
# However, the Openness is still needed.




abstract type Domain{T} end
abstract type AInner{T} <: Domain{T} end # TODO: Should no longer be needed when delayed types are supported.
const _Inner{T} = Union{T, AInner{T}} # TODO: Should no longer be needed when delayed types are supported.
const _LeftInner{T} = Union{NegativeInfinity, _Inner{T}} # TODO: Should no longer be needed when delayed types are supported.
const _RightInner{T} = Union{PositiveInfinity, _Inner{T}} # TODO: Should no longer be needed when delayed types are supported.

# abstract type ABound{O <: Openness, U <: _Inner} end # TODO: `_Inner` should be `Inner` when supported
# """
#     Bound{O <: Openness, U <: _Inner} <: ABound{O, U}

# An interval's bound type defined by `Openness` `O` and `Inner` `U`.
# """
# struct Bound{O <: Openness, U <: _Inner} <: ABound{O, U} end # TODO: `_Inner` should be `Inner` when supported. This way the user can use `Inner` without needing to change the API in the future.


# The aliases for the different combinations use the naming scheme
# [`Openness`][`Determination`]`Bound`
# but skip `Determination` if it is `Exact`.

# Note, that a `BoundType` is only the type of the bound without its value.
# As `BoundType` is a type parameter for `APartiallyDeterminedInterval`, using
# a `Bound` with value instead only a `BoundType` would mean that each interval
# had a different type for every bound value combination (in addition to the types).
# Nevertheless, the type aliases skip the `Type` in their name for brevity reasons.
# """
# struct BoundType{O <: Openness, D <: Determination} end
# const OpenBound = BoundType{Open, Exact}
# const OpenMinBound = BoundType{Open, Min}
# const OpenMaxBound = BoundType{Open, Max}
# const ClosedBound = BoundType{Closed, Exact}
# const ClosedMinBound = BoundType{Closed, Min}
# const ClosedMaxBound = BoundType{Closed, Max}

# left_string(::Type{Bound{O,U}}, x) where {O,U} = "$(O |> left_string)$U$x"
# right_string(::Type{Bound{O,U}}, x) where {O,U} = "$U$x$(O |> right_string)"
# left_string(::Type{Bound{O,U}}, x) where {O,U} = "$(O |> left_string)$x"
# right_string(::Type{Bound{O,U}}, x) where {O,U} = "$x$(O |> right_string)"
# left_string(::Type{<:Bound{O}}, x) where O = "$(O |> left_string)$x"
# right_string(::Type{<:Bound{O}}, x) where O = "$x$(O |> right_string)"
# left_string(::Type{<:ABound{O}}, x) where O = "$(O |> left_string)$x"
# right_string(::Type{<:ABound{O}}, x) where O = "$x$(O |> right_string)"

# Deliberately avoid `Symbol`s as type parameters, but use `Union`s and/or (singleton) immutable structs. This way, the compiler can immediately know not only that the number of types is finite, but also how may different types there are and thus the `Union` optimizations can hopefully always kick in. So, ideally, it should only need a single byte to encode all combinations. Note: This is only completely the case for a specific set of types. The general property is missing until delayed types are supported.
abstract type AInterval{T,Oₗ,Oᵣ,L,R} <: AInner{T} end # TODO: `AUncertainty` should be `Domain` when supported

# What would probably be a better definition, which is not supported at least including Julia 1.13:
# struct Interval{L <: Bound{<:Openness, UL <:_Inner{T}}, R <: Bound{<:Openness, UR <:_Inner{T}}} <: AInterval{L, R, T} where T
#     left::UL
#     right::UR
# end where {UL, UT}
# or
# struct Interval{B_L <: Bound{<:Openness, L}, B_R <: Bound{<:Openness, R}} where {T, L <: _Inner{T}, R <:_Inner{T}}
#     left::L
#     right::R
# end
# Rules for type parameters:
# - The elements in the (outer) comma separated list within curly braces define the type parameter
# - Every type parameter needs a name – anonymous constraints only work inside of the curly braces of another type
# - You can't bind a name to type constraint in such an inner constraint (matching)
# - So it's always a binding outside and anonymous inside
# - During the struct definition, they have type `TypeVar`, with fields `name::Symbol`, `lb::Any` and `ub::Any`. Evaluating the `name` does not work as this runs when the type parameter is not defined at all. The lower and upper bounds do not contain the concrete type in general.
# - There is no `where` support in parametric struct definitions. So you can't define a type variable by matching the type parameter of a type constraint. Thus, all needed types need to be defined first as additional types.
#
# Both uncertainties shall depend on the same `T`. Therefore, `T` must be defined before the uncertainties, although `T` being the last parameter would be more natural for internal usage when defining the different kind of concrete Interval aliases. All the other parameters are in the same order as in the naming scheme.
#
# The order of the parameters is defined according to the needs of the constructors, as they are effectively the API. `T` must be left of `L` and `R` due to the dependency. As `L` and `R` always follow from the constructor arguments, they are most often left out and therefore the last arguments.
# TODO: change to T, Oₗ <: LeftOpenness, Oᵣ <: RightOpenness, L <:_LeftInner{T}, R <:_RightInner{T}
"""
    Interval{T ≮: Interval, Oₗ <: LeftOpenness, Oᵣ <: RightOpenness, L <:_LeftInner{T}, R <:_RightInner{T}} <: AInterval{T, Oₗ, Oᵣ, L, R}

An interval where the endpoints can have uncertainty.

Infinite "endpoints" are always open. Finite endpoints can either be open or closed.
Finite endpoints can be fully determined or determined by their minimum and/or maximum
value, again open or closed.

Don't get confused by "mixed `Openness`" on an endpoint, e.g. `[(a1, a2), b]`. This means
that you have a closed interval. The left endpoint of the interval is uncertain, so we know
that `a1 < a < a2` holds for the true value `a` of the left endpoint.

When the uncertainty is `NegativeInfinity` or `PositiveInfinity`, the corresponding
`Openness` needs to be `Open`. Those two are limits rather than values, so no bound at
infinity holds a member and neither of them is an element type, where a float `Inf` is an
ordinary value of its type.

Elements of an `Interval` shall not be `Interval`s. This is because `T` is required to have
an ordering relation, which `Interval`s do not generally have. This restriction may be
relaxed in the future for special cases such as `Ray`s.
"""
struct Interval{T,Oₗ,Oᵣ,L,R} <: AInterval{T,Oₗ,Oᵣ,L,R}
    left::L
    right::R

    # At least with Julia 1.13 it is impossible to constraint the type parameters adequately. Therefore constraint at least the constructed objects.
    @inline function Interval{T,Oₗ,Oᵣ,L,R}(left::L, right::R) where {T, Oₗ <: LeftOpenness, Oᵣ <: RightOpenness, L <: _LeftInner{T}, R <: _RightInner{T}}
        # `Oₗ <: LeftOpenness` also covers `Union{}` and `LeftOpenness` itself.
        Oₗ isa typeunion(LeftOpenness) && Oᵣ isa typeunion(RightOpenness) || "Each bound needs a single `Openness`, not a union of them" |> ArgumentError |> throw
        (L == NegativeInfinity && Oₗ == LeftClosed || R == PositiveInfinity && Oᵣ == RightClosed ) && "Infinite closed bound detected" |> ArgumentError |> throw
        T === Union{} && "`Union{}` has no values, so it cannot be an element type" |> ArgumentError |> throw
        T <: Union{NegativeInfinity, PositiveInfinity} && "Elements of an `Interval` shall not be `-∞`/`∞`" |> ArgumentError |> throw
        T <: Interval && "Elements of an `Interval` shall not be `Interval`s" |> ArgumentError |> throw
        new{T, Oₗ, Oᵣ, L, R}(left, right)
    end
end

const RightRay{T, Oₗ <: LeftOpenness} = Interval{T, Oₗ, RightOpen, T, PositiveInfinity}
const LeftRay{T, Oᵣ <: RightOpenness} = Interval{T, LeftOpen, Oᵣ, NegativeInfinity, T}

const Line{T} = Interval{T, LeftOpen, RightOpen, NegativeInfinity, PositiveInfinity}
Line{T}() where T = Line{T}(-∞, +∞)

const Greater{T} = RightRay{T, LeftOpen}
const GreaterEqual{T} = RightRay{T, LeftClosed}
const Less{T} = LeftRay{T, RightOpen}
const LessEqual{T} = LeftRay{T, RightClosed}
const Comparison{T} = Union{Greater{T}, GreaterEqual{T}, Less{T}, LessEqual{T}}
const Comparisons = (Greater, GreaterEqual, Less, LessEqual)


const RegularInterval{T, Oₗ <: LeftOpenness, Oᵣ <: RightOpenness} = Interval{T,Oₗ,Oᵣ,T,T}
const OpenRegular{T} = RegularInterval{T, LeftOpen, RightOpen}
const ClosedRegular{T} = RegularInterval{T, LeftClosed, RightClosed}
const OpenClosedRegular{T} = RegularInterval{T, LeftOpen, RightClosed}
const ClosedOpenRegular{T} = RegularInterval{T, LeftClosed, RightOpen}
const CertainInterval{T} = Union{OpenRegular{T}, ClosedRegular{T}, OpenClosedRegular{T}, ClosedOpenRegular{T}}

const InnerInterval{T} = Union{CertainInterval{T}, Comparison{T}, Line{T}}
# The uncertainty can only be expressed with values within a *certain* range to avoid infinite recursion. So it is no contradiction at all to define the `Uncertainty` with a certain value, a certain ray or a certain interval, but instead it is an absolute necessity.
const Inner{T} = Union{T, InnerInterval{T}}
const LeftInner{T} = Union{NegativeInfinity, Inner{T}}
const RightInner{T} = Union{PositiveInfinity, Inner{T}}
const AllInner{T} = Union{LeftInner{T}, RightInner{T}}
# TODO: Check whether it makes sense to rename `Inner` to something else and then rename `AllInner` to `Inner`.

const OpenOpen{T} = Interval{T, LeftOpen, RightOpen}
const ClosedClosed{T} = Interval{T, LeftClosed, RightClosed}
const OpenClosed{T} = Interval{T, LeftOpen, RightClosed}
const ClosedOpen{T} = Interval{T, LeftClosed, RightOpen}

# Deliberately accept a bit more combinations, as the inner constructor implements the right constraint and we do not need to do it multiple times.
@inline Interval{T,Oₗ,Oᵣ,L,R}(inner) where {T,Oₗ,Oᵣ,L,R} =
    L == NegativeInfinity ? Interval{T, Oₗ, Oᵣ, NegativeInfinity, T}(-∞, convert_inner(T, inner)) :
    R == PositiveInfinity ? Interval{T, Oₗ, Oᵣ, T, PositiveInfinity}(convert_inner(T, inner), +∞) :
    "The types of the left and right bound need to be either `NegativeInfinity` or `PositiveInfinity`, respectively, to use this constructor" |> ArgumentError |> throw
# A `Type{C} where C <: Comparison` bound would also capture the concrete `Greater{Int}`, which has to reach the constructor above.
@inline (C::typeunion(Comparison))(x) = C{typeof(x)}(x)

# We could add a constructor which accept `(left::T, right::T) where T`, but this is already as efficient as it gets (only one method, everything statically evaluated).
@inline function Interval{Oₗ,Oᵣ}(left::L, right::R) where {Oₗ <: LeftOpenness, Oᵣ <: RightOpenness, L <: _LeftInner, R <: _RightInner}
    Tₗ = L <: InnerInterval ? eltype(L) : L
    Tᵣ = R <: InnerInterval ? eltype(R) : R
    T = Tₗ == NegativeInfinity && Tᵣ == PositiveInfinity ? "Provide the element type by calling `Line{T}()`" |> ArgumentError |> throw :
        Tₗ == NegativeInfinity ? Tᵣ :
        Tᵣ == PositiveInfinity ? Tₗ :
        promote_type(Tₗ, Tᵣ)

    T === Union{} && "Incompatible element types `Tₗ`: $Tₗ, `Tᵣ`: $Tᵣ" |> ArgumentError |> throw

    return Interval{T,Oₗ,Oᵣ}(left, right)
end
# Handle the `OpenOpen(x, y)` calls and the like. We wouldn't need this constructor if we defined `OpenOpen` and the like without `T`, but that wouldn't allow the user to define a simple conversion as in `OpenOpen{Int}(1, 4/2)` without defining at least one additional constructor for this, so that would not be a win.
@inline Interval{<:Any, Oₗ, Oᵣ}(left::_LeftInner, right::_RightInner) where {Oₗ,Oᵣ} = Interval{Oₗ,Oᵣ}(left, right)

@inline function Interval{T,Oₗ,Oᵣ}(left::_LeftInner, right::_RightInner) where {T, Oₗ <: LeftOpenness, Oᵣ <: RightOpenness}
    l, r = convert_inner(T, left), convert_inner(T, right)
    Interval{T, Oₗ, Oᵣ, typeof(l), typeof(r)}(l, r)
end

"""
    limits(x)

Return the limits of the values a bound can take, each with its openness.

The lower limit is `l` and its openness `₍`, the upper limit `r` and its openness `₎`. A bound with no uncertainty is the degenerate closed interval on its own value.
"""
@inline limits(x) = (l = x, ₍ = LeftClosed(), r = x, ₎ = RightClosed())
@inline limits(x::AInterval{<:Any,Oₗ,Oᵣ}) where {Oₗ,Oᵣ} = (l = x.left, ₍ = Oₗ(), r = x.right, ₎ = Oᵣ())

# `l` and `r` reach a bound as an interval in its own right, so the same four names describe an endpoint at either depth.
@inline function Base.getproperty(x::AInterval{<:Any,Oₗ,Oᵣ}, s::Symbol) where {Oₗ,Oᵣ}
    s === :l && return limits(getfield(x, :left))
    s === :r && return limits(getfield(x, :right))
    s === :₍ && return Oₗ()
    s === :₎ && return Oᵣ()
    return getfield(x, s)
end
Base.propertynames(x::AInterval) = (fieldnames(typeof(x))..., :l, :r, :₍, :₎)


@inline convert_inner(::Type, x::Union{NegativeInfinity, PositiveInfinity}) = x
@inline convert_inner(::Type{T}, x::InnerInterval) where T = convert(Interval{T}, x)
@inline convert_inner(::Type{T}, x) where T = convert(T, x)

@noinline inexact(::Type{TO}, x) where TO = throw(InexactError(:convert, TO, x))

@inline function Base.convert(TO::Type{<:Interval{T,Oₗ,Oᵣ,L,R} where {L <: _LeftInner, R <: _RightInner}}, x::AllInner) where {T, Oₗ <: LeftOpenness, Oᵣ <: RightOpenness}
    x isa TO && return x
    left = @something respell(T, convert_inner(T, x.left), x.₍, Oₗ()) inexact(TO, x)
    right = @something respell(T, convert_inner(T, x.right), x.₎, Oᵣ()) inexact(TO, x)
    return Interval{T, Oₗ, Oᵣ, typeof(left), typeof(right)}(left, right)
end

for (T, c, field) in zip(Comparisons, ('>', '≥', '<', '≤'), (:left, :left, :right, :right))
    @eval Base.Char(::Type{$T}) = $c
    @eval Base.print(io::IO, x::$T) = print(io, $c, x.$field)
end

Base.print(io::IO, x::AInterval{<:Any,Oₗ,Oᵣ}) where {Oₗ,Oᵣ} = print(io, Oₗ, x.left, ", ", x.right, Oᵣ)
Base.show(io::IO, ::MIME"text/plain", x::AInterval) = print(io, x)

Base.eltype(::Type{<:Interval{T}}) where T = T

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

# A step out of the element type drops the one endpoint that reaches beyond it, and that endpoint leaves `x` empty. The extreme stands in for it wherever a kept endpoint leaves `x` empty as well, which keeps every possible member set.
@inline narrowest_upper(::Type{T}, v, rr) where T = isnothing(v) && Base.hastypemax(T) && rr < typemax(T) ? typemax(T) : v
@inline narrowest_lower(::Type{T}, v, ll) where T = isnothing(v) && Base.hastypemax(T) && typemin(T) < ll ? typemin(T) : v

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

# Ordinals for the closed equivalents of a certain interval's limits, see `closed_ordinal` and `step_up`.
@inline left_ordinal(x) = isclosed(x.₍) ? x.left : step_up(x.left)
@inline right_ordinal(x) = isclosed(x.₎) ? x.right : step_down(x.right)

@inline function equal_clamped(x::InnerInterval{T}, y::InnerInterval{T})::Bool where T
    # Branchless, as data-dependent branches mispredict.
    ex, ey = isempty(x), isempty(y)
    same = isdiscrete(T) ?
        (left_ordinal(x) == left_ordinal(y)) & (right_ordinal(x) == right_ordinal(y)) :
        (x.₍ == y.₍) & (x.₎ == y.₎) & (x.left == y.left) & (x.right == y.right)
    # Where the first term holds, `ex` and `ey` agree, so `ex | same` works without `ey`.
    return (ex == ey) & (ex | same)
end

# Every pair of intervals needs a method, as `isequal` would otherwise fall back on `==` and inherit set identity.
Base.isequal(x::AInterval{T1,O1ₗ,O1ᵣ}, y::AInterval{T2,O2ₗ,O2ᵣ}) where {T1,O1ₗ,O1ᵣ,T2,O2ₗ,O2ᵣ} =
    T1 === T2 && O1ₗ === O2ₗ && O1ᵣ === O2ᵣ && isequal(x.left, y.left) && isequal(x.right, y.right)
# Machine numbers compare so cheaply that comparing both bounds beats branching after the first.
Base.isequal(x::AInterval{T,Oₗ,Oᵣ}, y::AInterval{T,Oₗ,Oᵣ}) where {T <: Union{Base.IEEEFloat, Base.BitInteger}, Oₗ, Oᵣ} =
    isequal(x.left, y.left) & isequal(x.right, y.right)

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

# A limit at infinity is the one that cannot be reached, so it is the one that stays open.
@inline canonical_left_openness(::NegativeInfinity) = LeftOpen
@inline canonical_left_openness(_) = LeftClosed
@inline canonical_right_openness(::PositiveInfinity) = RightOpen
@inline canonical_right_openness(_) = RightClosed

# A limit one step beyond the element type has no closed equivalent, which only `normalize` has to answer for.
@noinline no_canonical(x::AInterval{T}) where T = "`$x` has no canonical form, as a limit steps beyond `$T`" |> ArgumentError |> throw

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

"""
    canonical_bound(b, lo, hi)

Return the bound `b` rebuilt from its canonical limits as `[lo, hi]`, open only at an infinity, or as `lo` where `b` is a plain value.

An uncertain `b` stays an interval even where `lo == hi`, as in `[[3, 3], 7]`, so the result type follows from the type of `b` alone.
"""
@inline canonical_bound(::AInterval, lo, hi) = Interval{canonical_left_openness(lo), canonical_right_openness(hi)}(lo, hi)
@inline canonical_bound(_, lo, _) = lo

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

# …
# …₍
# …₎
# …₍₎(l::L, r::R) where {L,R}

# 2 …⁽ 4
# 2 …₍ 4