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

# `==` asks whether both hold the same members, so it answers `missing` wherever an uncertain endpoint leaves that open. `isequal` and `hash` stay structural and `Bool`, which `Dict` and `Set` need.
# A member is an order class, so the canonical bounds are compared with the order rather than with `==` on the values. That keeps the answer well defined for an element type whose `==` disagrees with its order.
# A differing element type falls through to the `===` fallback, as equal bounds do not mean equal contents: `(1, 2)` holds no `Int` where `(1.0, 2.0)` holds values by default.
# The `===` fallback compares representations, which `BigInt` and `BigFloat` bounds fail to share between equal values.
@inline order_equal(a, b) = a <= b && b <= a
@inline same_openness(::AInterval{<:Any,O1ₗ,O1ᵣ}, ::AInterval{<:Any,O2ₗ,O2ᵣ}) where {O1ₗ,O1ᵣ,O2ₗ,O2ᵣ} = O1ₗ == O2ₗ && O1ᵣ == O2ᵣ

# No member lies between an extreme of the element type and the infinity beyond it, so the two name the same limit. A type without extremes keeps its infinities.
@inline extreme_limit(::Type, v) = v
@inline extreme_limit(::Type{T}, v::NegativeInfinity) where T = Base.hastypemax(T) ? typemin(T) : v
@inline extreme_limit(::Type{T}, v::PositiveInfinity) where T = Base.hastypemax(T) ? typemax(T) : v
@inline extreme_limits(::Type{T}, limits::NamedTuple) where T = map(v -> extreme_limit(T, v), limits)

# The single value a bound stands for, or `missing` where its uncertainty leaves a choice.
@inline endpoint(b) = b
@inline function endpoint(b::AInterval)
    (; l, ₍, r, ₎) = limits(b)
    return order_equal(l, r) && isclosed(₍) && isclosed(₎) ? l : missing
end

function Base.:(==)(x::AInterval{T}, y::AInterval{T})::Union{Bool, Missing} where T
    empty_x, empty_y = isempty(x), isempty(y)
    (ismissing(empty_x) || ismissing(empty_y)) && return missing
    empty_x && return empty_y # every empty interval holds the same nothing
    empty_y && return false

    return if isdiscrete(T)
        # Both hold a value, so no limit runs out of the element type.
        xll, xlr, xrl, xrr = extreme_limits(T, something(canonical(x)))
        yll, ylr, yrl, yrr = extreme_limits(T, something(canonical(y)))
        # Equality can't be determined if any endpoint is uncertain.
        order_equal(xll, xlr) && order_equal(xrl, xrr) && order_equal(yll, ylr) && order_equal(yrl, yrr) || return missing
        # The intervals are equal if their canonical minimum and maximum agree.
        order_equal(xll, yll) && order_equal(xrr, yrr)
    else
        xl, xr = @✓(endpoint(x.left)), @✓(endpoint(x.right))
        yl, yr = @✓(endpoint(y.left)), @✓(endpoint(y.right))
        same_openness(x, y) && order_equal(xl, yl) && order_equal(xr, yr)
    end
end

# Every pair of intervals needs a method, as `isequal` would otherwise fall back on `==` and inherit set identity.
Base.isequal(x::AInterval{T1,O1ₗ,O1ᵣ}, y::AInterval{T2,O2ₗ,O2ᵣ}) where {T1,O1ₗ,O1ᵣ,T2,O2ₗ,O2ᵣ} =
    T1 === T2 && O1ₗ === O2ₗ && O1ᵣ === O2ᵣ && isequal(x.left, y.left) && isequal(x.right, y.right)

# `hash` takes the seed last, but a vararg has to come last, so the seed leads here.
@inline hash_all(h::UInt) = h
@inline hash_all(h::UInt, v, vs...) = hash_all(hash(v, h), vs...)

Base.hash(x::AInterval{T,Oₗ,Oᵣ}, h::UInt) where {T,Oₗ,Oᵣ} = hash_all(h, T, Oₗ, Oᵣ, x.left, x.right)

# `Infinities` gives its infinities no `hash` (2026-08-30) and Base's `Real` fallback needs a `decompose` they lack, so fill the gap only while it is one.
# Only the two singletons, as `Float64` overflows the stack for any further subtype of `RealInfinity`, and every float infinity hashes alike so the width is immaterial.
which(hash, Tuple{Union{NegativeInfinity, PositiveInfinity}, UInt}) === which(hash, Tuple{Real, UInt}) &&
    @eval Base.hash(x::Union{NegativeInfinity, PositiveInfinity}, h::UInt) = hash(Float64(x), h)

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
    successor(x::T)::Union{Nothing, T}

Return the neighbor above `x`, or `nothing` if `x`'s type holds no larger value.

Defining this method is what makes `T` discrete, so define [`predecessor`](@ref) along with it. Both owe the same contract:

- The neighbor has the type of `x`.
- `nothing` says the type holds no further value.
- No value of `T` lies between `x` and its neighbor
- `predecessor(x) < x < successor(x)`.
- `predecessor(successor(x)) == x` wherever both exist (=not `nothing`).

`T` itself needs `isless` and `==`. Where `Base.hastypemax(T)` holds, a limit at infinity names that extreme, so `>5` and `[6, typemax(T)]` hold the same members.
"""
(successor(x::T)::Union{Nothing, T}) where T <: Integer = Base.hastypemax(T) && x == typemax(x) ? nothing : x + oneunit(x)
# An infinite bound is its own neighbor in either direction, as it already lies beyond every value.
successor(x::Union{NegativeInfinity, PositiveInfinity}) = x

"""
    predecessor(x::T)::Union{Nothing, T}

Return the neighbor below `x`, or `nothing` if `x`'s type holds no smaller value.

Every type with a [`successor`](@ref) needs this method too, under the contract stated there.
"""
(predecessor(x::T)::Union{Nothing, T}) where T <: Integer = Base.hastypemax(T) && x == typemin(x) ? nothing : x - oneunit(x)
predecessor(x::Union{NegativeInfinity, PositiveInfinity}) = x

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

# The closed spelling of a limit, which a bound's limit reaches in two steps: once as the bound's own limit and once as the interval's.
@inline inwards(::Type{T}, v, o::LeftOpenness) where T = respell(T, v, o, LeftClosed())
@inline inwards(::Type{T}, v, o::RightOpenness) where T = respell(T, v, o, RightClosed())
@inline inwards(::Type{T}, v, o::Openness, p::Openness) where T = inwards(T, @∃(inwards(T, v, o)), p)

"""
    canonical_widest(x::AInterval)::Union{Nothing, NamedTuple{(:ll, :rr)}}

Return the limits of the widest interval `x` can be given its uncertainty.
"""
@inline function canonical_widest(x::AInterval{T})::Union{Nothing, NamedTuple{(:ll, :rr)}} where T
    (; ₍, l, r, ₎) = x
    ll = @∃ inwards(T, l.l, l.₍, ₍)
    rr = @∃ inwards(T, r.r, r.₎, ₎)
    return (; ll, rr)
end

"""
    canonical_narrowest(x::AInterval)::Union{Nothing, NamedTuple{(:lr, :rl)}}

Return the limits of the narrowest interval `x` can be given its uncertainty.
"""
@inline function canonical_narrowest(x::AInterval{T})::Union{Nothing, NamedTuple{(:lr, :rl)}} where T
    (; ₍, l, r, ₎) = x
    lr = @∃ inwards(T, l.r, l.₎, ₍)
    rl = @∃ inwards(T, r.l, r.₍, ₎)
    return (; lr, rl)
end

"""
    canonical(x::AInterval)::Union{Nothing, NamedTuple{(:ll, :lr, :rl, :rr)}}

Return the four limits of `x` given its uncertainty.
"""
@inline function canonical(x::AInterval{T})::Union{Nothing, NamedTuple{(:ll, :lr, :rl, :rr)}} where T
    (; ₍, l, r, ₎) = x
    (; ll, rr) = @∃ canonical_widest(x)
    lr = @∃ narrowest_upper(T, inwards(T, l.r, l.₎, ₍), rr)
    rl = @∃ narrowest_lower(T, inwards(T, r.l, r.₍, ₎), ll)
    return (; ll, lr, rl, rr)
end

# A step out of the element type drops the one endpoint that reaches beyond it, and that endpoint leaves `x` empty. The extreme stands in for it wherever a kept endpoint leaves `x` empty as well, which keeps every possible member set.
@inline narrowest_upper(::Type{T}, v, rr) where T = isnothing(v) && Base.hastypemax(T) && rr < typemax(T) ? typemax(T) : v
@inline narrowest_lower(::Type{T}, v, ll) where T = isnothing(v) && Base.hastypemax(T) && typemin(T) < ll ? typemin(T) : v

# A bound whose own limits conflict leaves no value for the endpoint.
@inline bound_isempty((; l, ₍, r, ₎)) = !(l <= r) || l == r && (isopen(₍) || isopen(₎))

"""
    isempty(x::AInterval)

Determine whether the interval contains no value.

If emptiness is determined, the function returns `true` or `false`. Otherwise, it returns `missing`.
"""
@inline function Base.isempty(x::AInterval{T})::Union{Bool, Missing} where T
    if isdiscrete(T)
        # Move every open limit inwards to compare closed limits.
        ll, rr = extreme_limits(T, @∃ canonical_widest(x) true)
        # `!<=` rather than `>`, as a limit that compares with nothing leaves no member either.
        @⊤⏎ !(ll <= rr)
        # A narrowest limit that steps out of the element type only shows that some endpoint empties `x`.
        lr, rl = extreme_limits(T, @∃ canonical_narrowest(x) missing)
        # An endpoint with no value to take leaves the interval with no members.
        @⊤⏎ !(ll <= lr) || !(rl <= rr)
        return lr <= rl ? false : missing
    else
        (; ₍, l, r, ₎) = x
        # any open side keeps a single shared endpoint out
        any_open = isopen(₍) || isopen(₎)
        # Use `!<=` instead of `>` to get the correct `missing` for non-comparing bounds like `NaN`.
        empty = bound_isempty(l) || bound_isempty(r) ||
            !(l.l <= r.r) || l.l == r.r && (isopen(l.₍) || isopen(r.₎) || any_open)
        nonempty = l.r < r.l || l.r == r.l && (!any_open || isopen(l.₎) || isopen(r.₍))

        # Only an empty bound satisfies both, and there `empty` is the one that answers.
        return empty || nonempty ? empty : missing
    end
end

# Help inference when emptiness is determined.
@inline Base.isempty(x::InnerInterval)::Bool = @invoke isempty(x::AInterval)

# A limit at infinity is the one that cannot be reached, so it is the one that stays open.
@inline canonical_left_openness(::NegativeInfinity) = LeftOpen
@inline canonical_left_openness(_) = LeftClosed
@inline canonical_right_openness(::PositiveInfinity) = RightOpen
@inline canonical_right_openness(_) = RightClosed

# A limit one step beyond the element type has no closed spelling, which only `normalize` has to answer for.
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
    (; ll, lr, rl, rr) = @something canonical(x) no_canonical(x)
    left, right = canonical_bound(x.left, ll, lr), canonical_bound(x.right, rl, rr)
    return Interval{T, canonical_left_openness(left), canonical_right_openness(right), typeof(left), typeof(right)}(left, right)
end

# Taking the shape from the bound that is already there keeps every type independent of the values.
@inline canonical_bound(::AInterval, lo, hi) = Interval{canonical_left_openness(lo), canonical_right_openness(hi)}(lo, hi)
@inline canonical_bound(_, lo, _) = lo

# The other end of `extreme_limit`: the same limit spelled as the infinity beyond the extreme, which is the spelling no element type outgrows.
@inline infinite_lower(::Type{T}, v) where T = Base.hastypemax(T) && v == typemin(T) ? -∞ : v
@inline infinite_upper(::Type{T}, v) where T = Base.hastypemax(T) && v == typemax(T) ? +∞ : v

# An endpoint that could take any value is the line over the element type.
@inline function simplified_bound(::Type{T}, lo, hi) where T
    l, h = infinite_lower(T, lo), infinite_upper(T, hi)
    return l isa NegativeInfinity && h isa PositiveInfinity ? Line{T}() :
        Interval{canonical_left_openness(l), canonical_right_openness(h)}(l, h)
end

"""
    simplify(x::Interval)

Return the canonical form of `x` with every uncertainty that is down to a single value dropped.

So `((1, 3), 7]` becomes `[3, 7]`, where [`normalize`](@ref) stops at `[[3, 3], 7]`. A limit at an extreme of the element type becomes the infinity beyond it, so `[5, typemax(Int)]` becomes `≥5`, which `normalize` leaves alone, and an endpoint that could take any value becomes `Line{T}()`.

Both take the same limits, but where none of them has a closed spelling, as for `([1, typemax(Int)], typemax(Int)]`, this call returns `x` unchanged rather than throwing as `normalize` does.

Whether a bound collapses follows from the values rather than from the types, so the result type is not inferable and the call allocates. Reach for `normalize` wherever that matters.
"""
function simplify(x::Interval{T,Oₗ,Oᵣ}) where {T,Oₗ,Oᵣ}
    # A dense element type has no limits to move, but a bound can still be down to one value.
    isdiscrete(T) || return Interval{T,Oₗ,Oᵣ}(coalesce(endpoint(x.left), x.left), coalesce(endpoint(x.right), x.right))
    (; ll, lr, rl, rr) = @something canonical(x) return x
    left = ll == lr ? infinite_lower(T, ll) : simplified_bound(T, ll, lr)
    right = rl == rr ? infinite_upper(T, rr) : simplified_bound(T, rl, rr)
    return Interval{T, canonical_left_openness(left), canonical_right_openness(right), typeof(left), typeof(right)}(left, right)
end

# …
# …₍
# …₎
# …₍₎(l::L, r::R) where {L,R}

# 2 …⁽ 4
# 2 …₍ 4