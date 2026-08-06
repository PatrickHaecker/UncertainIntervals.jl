

struct Open end
struct Closed end
const Openness = Union{Open, Closed}
isopen(x::Openness) = x == Open()
isclosed(x::Openness) = x == Closed()

left_tryparse(::Type{<:Openness}, c::AbstractChar) = c == '(' ? Open() : c == '[' ? Closed() : nothing
right_tryparse(::Type{<:Openness}, c::AbstractChar) = c == ')' ? Open() : c == ']' ? Closed() : nothing

left_string(::Type{Open}) = "("
left_string(::Type{Closed}) = "["
right_string(::Type{Open}) = ")"
right_string(::Type{Closed}) = "]"


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
abstract type AUncertainty{T} <: Domain{T} end # TODO: Should no longer be needed when delayed types are supported.
const _Uncertainty{T} = Union{T, AUncertainty{T}} # TODO: Should no longer be needed when delayed types are supported.
const _LeftUncertainty{T} = Union{NegativeInfinity, _Uncertainty{T}} # TODO: Should no longer be needed when delayed types are supported.
const _RightUncertainty{T} = Union{PositiveInfinity, _Uncertainty{T}} # TODO: Should no longer be needed when delayed types are supported.

abstract type ABound{O <: Openness, U <: _Uncertainty} end # TODO: `_Uncertainty` should be `Uncertainty` when supported
"""
    Bound{O <: Openness, U <: _Uncertainty} <: ABound{O, U}

An interval's bound type defined by `Openness` `O` and `Uncertainty` `U`.
"""
struct Bound{O <: Openness, U <: _Uncertainty} <: ABound{O, U} end # TODO: `_Uncertainty` should be `Uncertainty` when supported. This way the user can use `Uncertainty` without needing to change the API in the future.


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
left_string(::Type{<:ABound{O}}, x) where O = "$(O |> left_string)$x"
right_string(::Type{<:ABound{O}}, x) where O = "$x$(O |> right_string)"

# Deliberately avoid `Symbol`s as type parameters, but use `Union`s and/or (singleton) immutable structs. This way, the compiler can immediately know not only that the number of types is finite, but also how may different types there are and thus the `Union` optimizations can hopefully always kick in. So, ideally, it should only need a single byte to encode all combinations. Note: This is only completely the case for a specific set of types. The general property is missing until delayed types are supported.
abstract type AInterval{L <: Bound, R <: Bound, T} <: AUncertainty{T} end # TODO: `AUncertainty` should be `Domain` when supported
# abstract type AInterval{L_O <: Openness, R_O <: Openness, L, R, T} <: AUncertainty{T}  end

# Base.print(io::IO, x::AInterval{L,R}) where {L,R} = print(io, left_string(L, x.left), " … ", right_string(R, x.right))
Base.print(io::IO, x::AInterval{L,R}) where {L,R} = print(io, left_string(L, x.left), ", ", right_string(R, x.right))
# Base.print(io::IO, x::AInterval{OL, OR}) where {OL, OR} = print(io, OL |> left_string, x.left, " … ", x.right, OR |> right_string) # This would not need a `Bound` at all
Base.show(io::IO, ::MIME"text/plain", x::AInterval) = print(io, x)

# What would probably be a better definition, which is not supported at least including Julia 1.13:
# struct Interval{L <: Bound{<:Openness, UL <:_Uncertainty{T}}, R <: Bound{<:Openness, UR <:_Uncertainty{T}}} <: AInterval{L, R, T} where T
#     left::UL
#     right::UR
# end where {UL, UT}
# or
# struct Interval{B_L <: Bound{<:Openness, L}, B_R <: Bound{<:Openness, R}} where {T, L <: _Uncertainty{T}, R <:_Uncertainty{T}}
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
"""
    Interval{T, L <:_LeftUncertainty{T}, R <:_RightUncertainty{T}, OL <: Openness, OR <:Openness} <: AInterval{Bound{OL, L}, Bound{OR, R}, T}

An interval where the endpoints can have uncertainty.

Infinite "endpoints" are always open. Finite endpoints can either be open or closed.
Finite endpoints can be fully determined or determined by their minimum and/or maximum
value, again open or closed.

Don't get confused by "mixed `Openness`" on an endpoint, e.g. `[(a1, a2), b]`. This means
that you have a closed interval. The left endpoint of the interval is uncertain, so we know
that `a1 < a < a2` holds for the true value `a` of the left endpoint.

When the uncertainty is `NegativeInfinity` or `PositiveInfinity`, the corresponding
`Openness` needs to be `Open`.
"""
struct Interval{T, L <: _LeftUncertainty{T}, R <: _RightUncertainty{T}, OL <: Openness, OR <: Openness} <: AInterval{Bound{OL, L}, Bound{OR, R}, T}
    left::L
    right::R

    function Interval{T, L, R, OL, OR}(left::L, right::R) where {T, L <: _LeftUncertainty{T}, R <:_RightUncertainty{T}, OL <: Openness, OR <:Openness}
        (L == NegativeInfinity && OL == Closed || R == PositiveInfinity && OR == Closed ) && "Infinite closed bound detected" |> ArgumentError |> throw
        new{T, L, R, OL, OR}(left, right)
    end
end

# `Interval{OL,OR}(left::T, right::T)` is not possible with the above ordering of the type parameters.
# @inline Interval(::OL, ::OR, left::T, right::T) where {OL <: Openness, OR <: Openness, T} = Interval{T, T, T, OL, OR}(left, right)
@inline Interval(OL::Type{<:Openness}, OR::Type{<:Openness}, left::T, right::T) where T = Interval{T, T, T, OL, OR}(left, right)

# The aliases for the different combinations use the naming scheme: `Left`[`Uncertainty`]`Right`[`Uncertainty`][`Openness`][`Openness`]`Interval`
# with the additional rules
# - `Openness` is used only once, if both `Openness` values are identical for the interval, so we have {Open, Closed, OpenClosed, ClosedOpen}.
# - `Uncertainty` uses the following values {, OpenInf, OpenSup, ClosedInf, ClosedSup, OpenInfSup, ClosedInfSup, OpenInfClosedSup, ClosedInfOpenSup, } plus either `NegativeInfinity` or `PositiveInfinity`.
# - `Uncertainty` is used only once, if both `Uncertainty` values are identical for the interval. In this case `Left` and `Right` is omitted.
# - `Left` or `Right` is omitted if the corresponding bound is not uncertain, i.e. uses `T`.
# - `Uncertainty` and `Openness` is omitted and `Interval` is changed into `Ray`, if the corresponding uncertainty is infinite. This matches the terms used in http://www.mathmatique.com/naive-set-theory/relations/intervals
# This leads to the following number of combinations per T: (2 * (1 + 4 + 4))^2 + 2 * (9 * 2) = (2 * 9)^2 + 2 * 18 = 18^2 + 36 = 324 + 36 = 360



const RightOpenRay{T} = Interval{T, T, PositiveInfinity, Open, Open}
const LeftOpenRay{T} = Interval{T, NegativeInfinity, T, Open, Open}
const RightClosedRay{T} = Interval{T, T, PositiveInfinity, Closed, Open}
const LeftClosedRay{T} = Interval{T, NegativeInfinity, T, Open, Closed}
const CertainRay{T} = Union{RightOpenRay{T}, LeftOpenRay{T}, RightClosedRay{T}, LeftClosedRay{T}}

const OpenInf{T} = RightOpenRay{T}
const OpenSup{T} = LeftOpenRay{T}
const ClosedInf{T} = RightClosedRay{T}
const ClosedSup{T} = LeftClosedRay{T}
# This does not contain the extremum, i.e. minimum or maximum, for an open bound, but the infimum or supremum, so don't define it as such.
# const Extremum{T} = Union{OpenMin{T}, OpenMax{T}, ClosedMin{T}, ClosedMax{T}}

const OpenInterval{T} = Interval{T, T, T, Open, Open}
const ClosedInterval{T} = Interval{T, T, T, Closed, Closed}
const OpenClosedInterval{T} = Interval{T, T, T, Open, Closed}
const ClosedOpenInterval{T} = Interval{T, T, T, Closed, Open}
const CertainInterval{T} = Union{OpenInterval{T}, ClosedInterval{T}, OpenClosedInterval{T}, ClosedOpenInterval{T}}

const OpenInfOpenSup{T} = OpenInterval{T}
const ClosedInfClosedSup{T} = ClosedInterval{T}
const OpenInfClosedSup{T} = OpenClosedInterval{T}
const ClosedInfOpenSup{T} = ClosedOpenInterval{T}

const OpenOpen{T} = OpenInterval{T}
const ClosedClosed{T} = ClosedInterval{T}
const OpenClosed{T} = OpenClosedInterval{T}
const ClosedOpen{T} = ClosedOpenInterval{T}

# The uncertainty can only be expressed with values within a *certain* range to avoid infinite recursion. So it is no contradiction at all define the `Uncertainty` with a certain value, a certain ray or a certain interval, but instead it is an absolute necessity.
const Uncertainty{T} = Union{T, CertainRay{T}, CertainInterval{T}}
const LeftUncertainty{T} = Union{NegativeInfinity, Uncertainty{T}}
const RightUncertainty{T} = Union{PositiveInfinity, Uncertainty{T}}

# const LeftClosedInfOpenSupRightOpenInfClosedSupOpenClosedInterval{T} = Interval{T, ClosedOpen, OpenClosed, Open, Closed}
# const LeftClosedOpenRightOpenClosedIntervalOpenClosed{T} = Interval{T, ClosedOpen, OpenClosed, Open, Closed}
# const OpenClosedIntervalClosedOpenLeftOpenClosedRight{T} = Interval{T, ClosedOpen, OpenClosed, Open, Closed}
# const ClosedOpenLeftOpenClosedRightOpenClosedInterval{T} = Interval{T, ClosedOpen, OpenClosed, Open, Closed}
const ClosedOpenLeft_OpenClosedRight_OpenClosedInterval{T} = Interval{T, ClosedOpen, OpenClosed, Open, Closed}

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

# …
# …⁽ or …₍
# …⁾
# …⁽⁾(l::L, r::R) where {L,R}

# 2 …⁽ 4
# 2 …₍ 4


function Base.tryparse(::Type{<:CertainInterval{T}}, s::AbstractString) where T
    # We want to do `match(r"([([])\s*([^,]+)\s*,\s*([^,]+)\s*([)\]])", s)`, but allocation-free

    @⊤ ncodeunits(s) >= ncodeunits("(1,2)")
    @∃ left_openness = left_tryparse(Openness, s |> first)
    @∃ right_openness = right_tryparse(Openness, s |> last)

    @∃ n = findnext(',', s, 2) # 2 is correct, as the parenthesis/bracket at position [1] is ASCII
    @∄ findnext(',', s, n+1) # +1 is correct, as the comma is ASCII

    @∃ left = tryparse(T, @view s[2 : prevind(s, n)])
    @∃ right = tryparse(T, @view s[n+1 : lastindex(s)-1])

    # return Interval(left_openness, right_openness, left, right)::CertainInterval{T}
    # return Interval{T, T, T, left_openness |> typeof, right_openness |> typeof}(left, right)
    isclosed(left_openness) && isclosed(right_openness) && return ClosedClosed{T}(left, right)
    isopen(left_openness) && isopen(right_openness) && return OpenOpen{T}(left, right)
    isclosed(left_openness) && isopen(right_openness) && return ClosedOpen{T}(left, right)
    return OpenClosed{T}(left, right)
end



#=

=#
# function Base.parse(::Type{<:AInterval{T}}, s::AbstractString) where T # wrong parameter order in AInterval
function Base.tryparse(::Type{<:Interval{T}}, s::AbstractString) where T
    @⊤ ncodeunits(s) >= ncodeunits("(1,2)")
    @∃ left_openness = left_tryparse(Openness, s |> first)
    @∃ right_openness = right_tryparse(Openness, s |> last)

    is_certain_left = left_tryparse(Openness, s[2]) |> isnothing
    is_certain_right = right_tryparse(Openness, s[prevind(s, lastindex(s))]) |> isnothing

    # if is_certain_left &&

end

macro i_str(str::String)

    str |> typeof |> println
end

# Interval{Int, ClosedOpen, OpenClosed, Open, Closed}(2, 4) |> print




# #= Alternative:




# const OpenRightMinInterval{T} = Interval{OpenBound, OpenMinBound, T, T, T}

# const RightOpenRay{T} = Interval{OpenBound, OpenBound, NegativeInfinity, T, T}

# const LeftOpenMinMaxRightClosedMinMaxInterval{T} = Interval{OpenBound, ClosedBound, OpenInterval{T}, ClosedInterval{T}, T}
# =#

# # Both sides identical: [Openness][Determination]Interval
# # Same Openness, different Determination: [Openness]Left[LeftDetermination]Right[RightDetermination]Interval



# # Same Determination, different Openness: Left[LeftOpenness]Right[RightOpenness][Determination]Interval
# const LeftOpenRightClosedInterval{T} = Interval{OpenBound, ClosedBound, T}
# const LeftClosedRightOpenInterval{T} = Interval{ClosedBound, OpenBound, T}
# const MinLeftOpenRightClosedInterval{T} = Interval{OpenMinBound, ClosedMinBound, T}
# const MinLeftClosedRightOpenInterval{T} = Interval{ClosedMinBound, OpenMinBound, T}
# const MaxLeftOpenRightClosedInterval{T} = Interval{OpenMaxBound, ClosedMaxBound, T}
# const MaxLeftClosedRightOpenInterval{T} = Interval{ClosedMaxBound, OpenMaxBound, T}

# # All different: Left[LeftDetermination][LeftOpenness]Right[RightDetermination][RightOpenness]Interval
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
