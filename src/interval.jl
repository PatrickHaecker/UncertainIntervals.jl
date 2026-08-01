struct Open end
struct Closed end
const Openness = Union{Open, Closed}

left_string(::Type{Open}) = "("
left_string(::Type{Closed}) = "["
right_string(::Type{Open}) = ")"
right_string(::Type{Closed}) = "]"


"An exact value. This is the default you know from regular bounds."
struct Exact end
"The minimum known value, so ̂B <(=) B for the estimated ̂B of the true bound B"
struct Min end
"The maximum known value, so ̂B >(=) B for the estimated ̂B of the true bound B"
struct Max end
const Determination = Union{Exact, Min, Max}

Base.print(io::IO, ::Type{Exact}) = print(io, "")
Base.print(io::IO, ::Type{Min}) = print(io, "≥")
Base.print(io::IO, ::Type{Max}) = print(io, "≤")


"""
    BoundType{O <: Openness, D <: Determination}()

An interval's bound type defined by `Openness` `O` and `Determination` `D`.

The aliases for the different combinations use the naming scheme
[`Openness`][`Determination`]`Bound`
but skip `Determination` if it is `Exact`.

Note, that a `BoundType` is only the type of the bound without its value.
As `BoundType` is a type parameter for `APartiallyDeterminedInterval`, using
a `Bound` with value instead only a `BoundType` would mean that each interval
had a different type for every bound value combination (in addition to the types).
Nevertheless, the type aliases skip the `Type` in their name for brevity reasons.
"""
struct BoundType{O <: Openness, D <: Determination} end
const OpenBound = BoundType{Open, Exact}
const OpenMinBound = BoundType{Open, Min}
const OpenMaxBound = BoundType{Open, Max}
const ClosedBound = BoundType{Closed, Exact}
const ClosedMinBound = BoundType{Closed, Min}
const ClosedMaxBound = BoundType{Closed, Max}

left_string(::Type{BoundType{O,D}}, x) where {O,D} = "$(O |> left_string)$D$x"
right_string(::Type{BoundType{O,D}}, x) where {O,D} = "$D$x$(O |> right_string)"


# Deliberately avoid `Symbol`s as type parameters, but use `Union`s. This way, the compiler can immediately know not only that the number of types is finite, but also how may different types there are and thus the `Union` optimizations can hopefully always kick in. So, ideally, it should only need a single byte to encode all combinations.
# abstract type APartiallyDeterminedInterval{L <: BoundType, R <: BoundType, T} <: Domain{T} end

abstract type AInterval{L <: BoundType, R <: BoundType, T_L, T_R, T} <: Domain{T} end

"""
A type which can model intervals where infinite "endpoints" are always open and finite endpoints can either be open or closed. Finite endpoints can be fully determined or determined by their minimum and/or maximum value.
"""
struct Interval{L <: BoundType, R <: BoundType, T_L, T_R, T} <: APartiallyDeterminedInterval{L,R,T_L,T_R,T}
    left::T_L
    right::T_R
end

"""
    struct Interval{L <: BoundType, R <: BoundType, T}(left::T, right::T)

A general interval, where each bound might either be exactly known or only
their minimum or maximum value.

The aliases for the different combinations use the naming scheme
`Left`[`Openness`][`Determination`]`Right`[`Openness`][`Determination`]`Interval`
with the additional rules
- `Openness` and/or `Determination` are pulled ahead and used only once, if they are identical for left and right
- `Exact` is omitted
- `Left` or `Right` are ommitted if they were empty due to the rules above
"""
# struct Interval{L <: BoundType, R <: BoundType, T} <: APartiallyDeterminedInterval{L,R,T}
#     left::T
#     right::T
# end
# Interval{L,R}(left::T, right::T) where {L <: BoundType, R <: BoundType, T} = Interval{L,R,T}(left, right)

Base.print(io::IO, x::APartiallyDeterminedInterval{L,R}) where {L,R} = print(io, left_string(L, x.left), " … ", right_string(R, x.right))
Base.show(io::IO, ::MIME"text/plain", x::APartiallyDeterminedInterval) = print(io, x)


struct Left end
struct Right end
const Direction = Union{Left, Right}

# TODO: common supertype below Domain?
abstract type APartiallyDeterminedRay{D <: Direction, B <: BoundType, T} <: Domain{T} end
struct PartiallyDeterminedRay{D <: Direction, B <: BoundType, T} <: APartiallyDeterminedRay{D,B,T}
    value::T # value of the bound
end

const PartiallyDeterminedGeneralInterval{T} = Union{Interval{<:BoundType, <:BoundType, T}, PartiallyDeterminedRay{<:Direction,<:BoundType, T}}

# Use names from http://www.mathmatique.com/naive-set-theory/relations/intervals
const RightOpenRay{T}      = PartiallyDeterminedRay{Right, OpenBound, T}
const RightOpenMinRay{T}   = PartiallyDeterminedRay{Right, OpenMinBound, T}
const RightOpenMaxRay{T}   = PartiallyDeterminedRay{Right, OpenMaxBound, T}

const RightClosedRay{T}    = PartiallyDeterminedRay{Right, ClosedBound, T}
const RightClosedMinRay{T} = PartiallyDeterminedRay{Right, ClosedMinBound, T}
const RightClosedMaxRay{T} = PartiallyDeterminedRay{Right, ClosedMaxBound, T}

const LeftOpenRay{T}       = PartiallyDeterminedRay{Left, OpenBound, T}
const LeftOpenMinRay{T}    = PartiallyDeterminedRay{Left, OpenMinBound, T}
const LeftOpenMaxRay{T}    = PartiallyDeterminedRay{Left, OpenMaxBound, T}

const LeftClosedRay{T}     = PartiallyDeterminedRay{Left, ClosedBound, T}
const LeftClosedMinRay{T}  = PartiallyDeterminedRay{Left, ClosedMinBound, T}
const LeftClosedMaxRay{T}  = PartiallyDeterminedRay{Left, ClosedMaxBound, T}

#= Alternative:



const OpenInterval{T} = Interval{OpenBound, OpenBound, T, T, T}

const OpenRightMinInterval{T} = Interval{OpenBound, OpenMinBound, T, T, T}

const RightOpenRay{T} = Interval{OpenBound, OpenBound, NegativeInfinity, T, T}

const LeftOpenMinMaxRightClosedMinMaxInterval{T} = Interval{OpenBound, ClosedBound, OpenInterval{T}, ClosedInterval{T}, T}
=#

# Both sides identical: [Openness][Determination]Interval
const OpenInterval{T} = Interval{OpenBound, OpenBound, T}
const ClosedInterval{T} = Interval{ClosedBound, ClosedBound, T}
const OpenMinInterval{T} = Interval{OpenMinBound, OpenMinBound, T}
const ClosedMinInterval{T} = Interval{ClosedMinBound, ClosedMinBound, T}
const OpenMaxInterval{T} = Interval{OpenMaxBound, OpenMaxBound, T}
const ClosedMaxInterval{T} = Interval{ClosedMaxBound, ClosedMaxBound, T}

# Same Openness, different Determination: [Openness]Left[LeftDetermination]Right[RightDetermination]Interval
const OpenRightMinInterval{T} = Interval{OpenBound, OpenMinBound, T}
const OpenRightMaxInterval{T} = Interval{OpenBound, OpenMaxBound, T}
const OpenLeftMinInterval{T} = Interval{OpenMinBound, OpenBound, T}
const OpenLeftMinRightMaxInterval{T} = Interval{OpenMinBound, OpenMaxBound, T}
const OpenLeftMaxInterval{T} = Interval{OpenMaxBound, OpenBound, T}
const OpenLeftMaxRightMinInterval{T} = Interval{OpenMaxBound, OpenMinBound, T}

const ClosedRightMinInterval{T} = Interval{ClosedBound, ClosedMinBound, T}
const ClosedRightMaxInterval{T} = Interval{ClosedBound, ClosedMaxBound, T}
const ClosedLeftMinInterval{T} = Interval{ClosedMinBound, ClosedBound, T}
const ClosedLeftMinRightMaxInterval{T} = Interval{ClosedMinBound, ClosedMaxBound, T}
const ClosedLeftMaxInterval{T} = Interval{ClosedMaxBound, ClosedBound, T}
const ClosedLeftMaxRightMinInterval{T} = Interval{ClosedMaxBound, ClosedMinBound, T}

# Same Determination, different Openness: Left[LeftOpenness]Right[RightOpenness][Determination]Interval
const LeftOpenRightClosedInterval{T} = Interval{OpenBound, ClosedBound, T}
const LeftClosedRightOpenInterval{T} = Interval{ClosedBound, OpenBound, T}
const MinLeftOpenRightClosedInterval{T} = Interval{OpenMinBound, ClosedMinBound, T}
const MinLeftClosedRightOpenInterval{T} = Interval{ClosedMinBound, OpenMinBound, T}
const MaxLeftOpenRightClosedInterval{T} = Interval{OpenMaxBound, ClosedMaxBound, T}
const MaxLeftClosedRightOpenInterval{T} = Interval{ClosedMaxBound, OpenMaxBound, T}

# All different: Left[LeftDetermination][LeftOpenness]Right[RightDetermination][RightOpenness]Interval
const LeftOpenRightClosedMinInterval{T} = Interval{OpenBound, ClosedMinBound, T}
const LeftOpenRightClosedMaxInterval{T} = Interval{OpenBound, ClosedMaxBound, T}
const LeftOpenMinRightClosedInterval{T} = Interval{OpenMinBound, ClosedBound, T}
const LeftOpenMinRightClosedMaxInterval{T} = Interval{OpenMinBound, ClosedMaxBound, T}
const LeftOpenMaxRightClosedInterval{T} = Interval{OpenMaxBound, ClosedBound, T}
const LeftOpenMaxRightClosedMinInterval{T} = Interval{OpenMaxBound, ClosedMinBound, T}

const LeftClosedRightOpenMinInterval{T} = Interval{ClosedBound, OpenMinBound, T}
const LeftClosedRightOpenMaxInterval{T} = Interval{ClosedBound, OpenMaxBound, T}
const LeftClosedMinRightOpenInterval{T} = Interval{ClosedMinBound, OpenBound, T}
const LeftClosedMinRightOpenMaxInterval{T} = Interval{ClosedMinBound, OpenMaxBound, T}
const LeftClosedMaxRightOpenInterval{T} = Interval{ClosedMaxBound, OpenBound, T}
const LeftClosedMaxRightOpenMinInterval{T} = Interval{ClosedMaxBound, OpenMinBound, T}
