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
`Openness` needs to be `Open`.

Elements of an `Interval` shall not be `Interval`s. This is because `T` is required to have
an ordering relation, which `Interval`s do not generally have. This restriction may be
relaxed in the future for special cases such as `Ray`s.
"""
struct Interval{T,Oₗ,Oᵣ,L,R} <: AInterval{T,Oₗ,Oᵣ,L,R}
    left::L
    right::R

    # At least with Julia 1.13 it is impossible to constraint the type parameters adequately. Therefore constraint at least the constructed objects.
    @inline function Interval{T,Oₗ,Oᵣ,L,R}(left::L, right::R) where {T, Oₗ <: LeftOpenness, Oᵣ <: RightOpenness, L <: _LeftInner{T}, R <: _RightInner{T}}
        (L == NegativeInfinity && Oₗ == LeftClosed || R == PositiveInfinity && Oᵣ == RightClosed ) && "Infinite closed bound detected" |> ArgumentError |> throw
        T <: Interval && "Elements of an `Interval` shall not be `Interval`s" |> ArgumentError |> throw
        new{T, Oₗ, Oᵣ, L, R}(left, right)
    end
end

const RightRay{T, Oₗ <: LeftOpenness} = Interval{T, Oₗ, RightOpen, T, PositiveInfinity}
const LeftRay{T, Oᵣ <: RightOpenness} = Interval{T, LeftOpen, Oᵣ, NegativeInfinity, T}
const RightOpenRay{T} = RightRay{T, LeftOpen}
const LeftOpenRay{T} = LeftRay{T, RightOpen}
const RightClosedRay{T} = RightRay{T, LeftClosed}
const LeftClosedRay{T} = LeftRay{T, RightClosed}
const CertainRay{T} = Union{RightOpenRay{T}, LeftOpenRay{T}, RightClosedRay{T}, LeftClosedRay{T}}

const OpenInf{T} = RightOpenRay{T}
const OpenSup{T} = LeftOpenRay{T}
const ClosedInf{T} = RightClosedRay{T}
const ClosedSup{T} = LeftClosedRay{T}
# This does not contain the extremum, i.e. minimum or maximum, for an open bound, but the infimum or supremum, so don't define it as such.
# const Extremum{T} = Union{OpenMin{T}, OpenMax{T}, ClosedMin{T}, ClosedMax{T}}

# const Greater{T} = RightOpenRay{T}
# const Superior{T} = LeftOpenRay{T}
# const Less{T} = RightClosedRay{T}
# const Inferior{T} = LeftClosedRay{T}
# const Comparison{T} = Union{Greater{T}, Superior{T}, Less{T}, Inferior{T}}

const LessThan{T} = LeftOpenRay{T}
const AtMost{T} = LeftClosedRay{T}
const AtLeast{T} = RightClosedRay{T}
const GreaterThan{T} = RightOpenRay{T}

const Greater{T} = RightOpenRay{T}
const GreaterEqual{T} = RightClosedRay{T}
const Less{T} = LeftOpenRay{T}
const LessEqual{T} = LeftClosedRay{T}
const Comparison{T} = Union{Greater{T}, GreaterEqual{T}, Less{T}, LessEqual{T}}
const Comparisons = (Greater, GreaterEqual, Less, LessEqual)


const RegularInterval{T, Oₗ <: LeftOpenness, Oᵣ <: RightOpenness} = Interval{T,Oₗ,Oᵣ,T,T}
const OpenRegular{T} = RegularInterval{T, LeftOpen, RightOpen}
const ClosedRegular{T} = RegularInterval{T, LeftClosed, RightClosed}
const OpenClosedRegular{T} = RegularInterval{T, LeftOpen, RightClosed}
const ClosedOpenRegular{T} = RegularInterval{T, LeftClosed, RightOpen}
const CertainInterval{T} = Union{OpenRegular{T}, ClosedRegular{T}, OpenClosedRegular{T}, ClosedOpenRegular{T}}

const OpenInfOpenSup{T} = OpenRegular{T}
const ClosedInfClosedSup{T} = ClosedRegular{T}
const OpenInfClosedSup{T} = OpenClosedRegular{T}
const ClosedInfOpenSup{T} = ClosedOpenRegular{T}

const InnerInterval{T} = Union{CertainRay{T}, CertainInterval{T}}
# The uncertainty can only be expressed with values within a *certain* range to avoid infinite recursion. So it is no contradiction at all to define the `Uncertainty` with a certain value, a certain ray or a certain interval, but instead it is an absolute necessity.
const Inner{T} = Union{T, InnerInterval{T}}
const LeftInner{T} = Union{NegativeInfinity, Inner{T}}
const RightInner{T} = Union{PositiveInfinity, Inner{T}}
const AllInner{T} = Union{LeftInner{T}, RightInner{T}}
# TODO: Check whether it makes sense to rename `Inner` to something else and then rename `AllInner` to `Inner`.

const OpenOpenInner{T} = OpenRegular{T}
const ClosedClosedInner{T} = ClosedRegular{T}
const OpenClosedInner{T} = OpenClosedRegular{T}
const ClosedOpenInner{T} = ClosedOpenRegular{T}

const OpenOpen{T} = Interval{T, LeftOpen, RightOpen}
const ClosedClosed{T} = Interval{T, LeftClosed, RightClosed}
const OpenClosed{T} = Interval{T, LeftOpen, RightClosed}
const ClosedOpen{T} = Interval{T, LeftClosed, RightOpen}

@inline Greater(left::T) where T = RightRay{T, LeftOpen}(left, +∞)
@inline GreaterEqual(left::T) where T = RightRay{T, LeftClosed}(left, +∞)
@inline Less(right::T) where T = LeftRay{T, RightOpen}(-∞, right)
@inline LessEqual(right::T) where T = LeftRay{T, RightClosed}(-∞, right)

@inline OpenOpen(left::_LeftInner{T}, right::_RightInner{T}) where T = Interval{LeftOpen, RightOpen}(left, right)
@inline ClosedClosed(left::_LeftInner{T}, right::_RightInner{T}) where T = Interval{LeftClosed, RightClosed}(left, right)
@inline OpenClosed(left::_LeftInner{T}, right::_RightInner{T}) where T = Interval{LeftOpen, RightClosed}(left, right)
@inline ClosedOpen(left::_LeftInner{T}, right::_RightInner{T}) where T = Interval{LeftClosed, RightOpen}(left, right)

# We could add a constructor which accept `(left::T, right::T) where T`, but this is already as efficient as it gets (only one method, everything statically evaluatable).
@inline function Interval{Oₗ, Oᵣ}(left::L, right::R) where {Oₗ <: LeftOpenness, Oᵣ <: RightOpenness, L <: _LeftInner, R <: _RightInner}
    Tₗ = L <: InnerInterval ? eltype(L) : L
    Tᵣ = R <: InnerInterval ? eltype(R) : R
    T = Tₗ == NegativeInfinity && Tᵣ == PositiveInfinity ? "Provide the element type by calling `Interval{T}(-∞, ∞)`" |> ArgumentError |> throw :
        Tₗ == NegativeInfinity ? Tᵣ :
        Tᵣ == PositiveInfinity ? Tₗ :
        promote_type(Tₗ, Tᵣ)

    T === Union{} && "Incompatible element types `Tₗ`: $Tₗ, `Tᵣ`: $Tᵣ" |> ArgumentError |> throw

    return Interval{T, Oₗ, Oᵣ}(left, right)
end

@inline function Interval{T,Oₗ,Oᵣ}(left::_LeftInner, right::_RightInner) where {T, Oₗ <: LeftOpenness, Oᵣ <: RightOpenness}
    l, r = convert_inner(T, left), convert_inner(T, right)
    Interval{T, Oₗ, Oᵣ, typeof(l), typeof(r)}(l, r)
end
@inline Interval{T,oₗ,oᵣ}(l::_LeftInner, r::_RightInner) where {T, oₗ, oᵣ} = Interval{T, typeof(oₗ), typeof(oᵣ)}(l, r)


@inline convert_inner(::Type, x::Union{NegativeInfinity, PositiveInfinity}) = x
@inline convert_inner(::Type{T}, x::InnerInterval) where T = convert(Interval{T}, x)
@inline convert_inner(::Type{T}, x) where T = convert(T, x)

@inline function Base.convert(TO::Type{<:Interval{T,Oₗ,Oᵣ,L,R} where {L <: _LeftInner, R <: _RightInner}}, x::AllInner) where {T, Oₗ <: LeftOpenness, Oᵣ <: RightOpenness}
    x isa TO && return x
    left, right = convert(T, x.left), convert(T, x.right)
    return Interval{T, Oₗ, Oᵣ, typeof(left), typeof(right)}(left, right)
end

for (T, c, field) in zip(Comparisons, ('>', '≥', '<', '≤'), (:left, :left, :right, :right))
    @eval Base.Char(::Type{$T}) = $c
    @eval Base.print(io::IO, x::$T) = print(io, $c, x.$field)
    @eval Base.print(x::$T) = print(Base.stdout, x)
end

Base.print(io::IO, x::AInterval{T,Oₗ,Oᵣ}) where {T,Oₗ,Oᵣ} = print(io, Oₗ, x.left, ", ", x.right, Oᵣ)
Base.print(x::AInterval{T,Oₗ,Oᵣ}) where {T,Oₗ,Oᵣ} = print(Base.stdout, x)
Base.show(io::IO, ::MIME"text/plain", x::AInterval) = print(io, x)

Base.eltype(::Type{<:Interval{T}}) where T = T

# …
# …⁽ or …₍
# …⁾
# …⁽⁾(l::L, r::R) where {L,R}

# 2 …⁽ 4
# 2 …₍ 4



# The aliases for the different combinations use the naming scheme: `Left`[`Uncertainty`]`Right`[`Uncertainty`][`Openness`][`Openness`]`Interval`
# with the additional rules
# - `Openness` is used only once, if both `Openness` values are identical for the interval, so we have {Open, Closed, OpenClosed, ClosedOpen}.
# - `Uncertainty` uses the following values {, OpenInf, OpenSup, ClosedInf, ClosedSup, OpenInfSup, ClosedInfSup, OpenInfClosedSup, ClosedInfOpenSup, } plus either `NegativeInfinity` or `PositiveInfinity`.
# - `Uncertainty` is used only once, if both `Uncertainty` values are identical for the interval. In this case `Left` and `Right` is omitted.
# - `Left` or `Right` is omitted if the corresponding bound is not uncertain, i.e. uses `T`.
# - `Uncertainty` and `Openness` is omitted and `Interval` is changed into `Ray`, if the corresponding uncertainty is infinite. This matches the terms used in http://www.mathmatique.com/naive-set-theory/relations/intervals
# This leads to the following number of combinations per T: (2 * (1 + 4 + 4))^2 + 2 * (9 * 2) = (2 * 9)^2 + 2 * 18 = 18^2 + 36 = 324 + 36 = 360


# const LeftClosedInfOpenSupRightOpenInfClosedSupOpenClosedInterval{T} = Interval{T, ClosedOpen, OpenClosed, Open, Closed}
# const LeftClosedOpenRightOpenClosedIntervalOpenClosed{T} = Interval{T, ClosedOpen, OpenClosed, Open, Closed}
# const OpenClosedIntervalClosedOpenLeftOpenClosedRight{T} = Interval{T, ClosedOpen, OpenClosed, Open, Closed}
# const ClosedOpenLeftOpenClosedRightOpenClosedInterval{T} = Interval{T, ClosedOpen, OpenClosed, Open, Closed}
# const ClosedOpenLeft_OpenClosedRight_OpenClosedInterval{T} = Interval{T, ClosedOpen, OpenClosed, LeftOpen, RightClosed}

# const RightOpenMinRay{T}   = Interval{Open, Open, OpenMin{T}, PositiveInfinity, T}
# const RightOpenMaxRay{T}   = Interval{Open, Open, OpenMax{T}, PositiveInfinity, T}
# const LeftOpenMinRay{T}    = Interval{Open, Open, NegativeInfinity, OpenMin{T}, T}
# const LeftOpenMaxRay{T}    = Interval{Open, Open, NegativeInfinity, OpenMax{T}, T}

# const RightClosedMinRay{T} = Interval{Closed, Open, ClosedMin{T}, PositiveInfinity, T}
# const RightClosedMaxRay{T} = Interval{Closed, Open, ClosedMax{T}, PositiveInfinity, T}
# const LeftClosedMinRay{T}  = Interval{Open, Closed, NegativeInfinity, ClosedMin{T}, T}
# const LeftClosedMaxRay{T}  = Interval{Open, Closed, NegativeInfinity, ClosedMax{T}, T}




# const OpenMinInterval{T} = Interval{Open, Open, OpenMin{T}, OpenMin{T}, T}
# const OpenMaxInterval{T} = Interval{Open, Open, OpenMax{T}, OpenMax{T}, T}
# const ClosedMinInterval{T} = Interval{Closed, Closed, ClosedMin{T}, ClosedMin{T}, T}
# const ClosedMaxInterval{T} = Interval{Closed, Closed, ClosedMax{T}, ClosedMax{T}, T}


# const OpenRightMinInterval{T} = Interval{Open, Open, OpenBound, OpenMinBound, T}
# const OpenRightMaxInterval{T} = Interval{Open, Open, OpenBound, OpenMaxBound, T}
# const OpenLeftMinInterval{T} = Interval{Open, Open, OpenMinBound, OpenBound, T}
# const OpenLeftMinRightMaxInterval{T} = Interval{Open, Open, OpenMinBound, OpenMaxBound, T}
# const OpenLeftMaxInterval{T} = Interval{Open, Open, OpenMaxBound, OpenBound, T}
# const OpenLeftMaxRightMinInterval{T} = Interval{Open, Open, OpenMaxBound, OpenMinBound, T}

# const ClosedRightMinInterval{T} = Interval{ClosedBound, ClosedMinBound, T}
# const ClosedRightMaxInterval{T} = Interval{ClosedBound, ClosedMaxBound, T}
# const ClosedLeftMinInterval{T} = Interval{ClosedMinBound, ClosedBound, T}
# const ClosedLeftMinRightMaxInterval{T} = Interval{ClosedMinBound, ClosedMaxBound, T}
# const ClosedLeftMaxInterval{T} = Interval{ClosedMaxBound, ClosedBound, T}
# const ClosedLeftMaxRightMinInterval{T} = Interval{ClosedMaxBound, ClosedMinBound, T}

#= Alternative:




# const OpenRightMinInterval{T} = Interval{OpenBound, OpenMinBound, T, T, T}

# const RightOpenRay{T} = Interval{OpenBound, OpenBound, NegativeInfinity, T, T}

# const LeftOpenMinMaxRightClosedMinMaxInterval{T} = Interval{OpenBound, ClosedBound, OpenInterval{T}, ClosedInterval{T}, T}
# =#

# Both sides identical: [Openness][Determination]Interval
# Same Openness, different Determination: [Openness]Left[LeftDetermination]Right[RightDetermination]Interval



# Same Determination, different Openness: Left[LeftOpenness]Right[RightOpenness][Determination]Interval
# const LeftOpenRightClosedInterval{T} = Interval{OpenBound, ClosedBound, T}
# const LeftClosedRightOpenInterval{T} = Interval{ClosedBound, OpenBound, T}
# const MinLeftOpenRightClosedInterval{T} = Interval{OpenMinBound, ClosedMinBound, T}
# const MinLeftClosedRightOpenInterval{T} = Interval{ClosedMinBound, OpenMinBound, T}
# const MaxLeftOpenRightClosedInterval{T} = Interval{OpenMaxBound, ClosedMaxBound, T}
# const MaxLeftClosedRightOpenInterval{T} = Interval{ClosedMaxBound, OpenMaxBound, T}

# All different: Left[LeftDetermination][LeftOpenness]Right[RightDetermination][RightOpenness]Interval
# const LeftOpenRightClosedMinInterval{T} = Interval{OpenBound, ClosedMinBound, T}
# const LeftOpenRightClosedMaxInterval{T} = Interval{OpenBound, ClosedMaxBound, T}
# const LeftOpenMinRightClosedInterval{T} = Interval{OpenMinBound, ClosedBound, T}
# const LeftOpenMinRightClosedMaxInterval{T} = Interval{OpenMinBound, ClosedMaxBound, T}
# const LeftOpenMaxRightClosedInterval{T} = Interval{OpenMaxBound, ClosedBound, T}
# const LeftOpenMaxRightClosedMinInterval{T} = Interval{OpenMaxBound, ClosedMinBound, T}

# const LeftClosedRightOpenMinInterval{T} = Interval{ClosedBound, OpenMinBound, T}
# const LeftClosedRightOpenMaxInterval{T} = Interval{ClosedBound, OpenMaxBound, T}
# const LeftClosedMinRightOpenInterval{T} = Interval{ClosedMinBound, OpenBound, T}
# const LeftClosedMinRightOpenMaxInterval{T} = Interval{ClosedMinBound, OpenMaxBound, T}
# const LeftClosedMaxRightOpenInterval{T} = Interval{ClosedMaxBound, OpenBound, T}
# const LeftClosedMaxRightOpenMinInterval{T} = Interval{ClosedMaxBound, OpenMinBound, T}
