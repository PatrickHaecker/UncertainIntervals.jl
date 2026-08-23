struct LeftOpen end
struct LeftClosed end
struct RightOpen end
struct RightClosed end

const LeftOpenness = Union{LeftOpen, LeftClosed}
const RightOpenness = Union{RightOpen, RightClosed}
const Open = Union{LeftOpen, RightOpen}
const Closed = Union{LeftClosed, RightClosed}
const Openness = Union{Open, Closed}


isopen(x::LeftOpenness) = x == LeftOpen()
isclosed(x::LeftOpenness) = x == LeftClosed()
isopen(x::RightOpenness) = x == RightOpen()
isclosed(x::RightOpenness) = x == RightClosed()

Base.tryparse(::Type{<:LeftOpenness}, c::AbstractChar) = c == '(' ? LeftOpen() : c == '[' ? LeftClosed() : nothing
Base.tryparse(::Type{<:RightOpenness}, c::AbstractChar) = c == ')' ? RightOpen() : c == ']' ? RightClosed() : nothing

Base.print(io::IO, ::Type{LeftOpen}) = print(io, "(")
Base.print(io::IO, ::Type{LeftClosed}) = print(io, "[")
Base.print(io::IO, ::Type{RightOpen}) = print(io, ")")
Base.print(io::IO, ::Type{RightClosed}) = print(io, "]")

# left_string(::Type{Open}) = "("
# left_string(::Type{Closed}) = "["
# right_string(::Type{Open}) = ")"
# right_string(::Type{Closed}) = "]"


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
const _Inner{T} = Union{T, AUncertainty{T}} # TODO: Should no longer be needed when delayed types are supported.
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
# abstract type AInterval{L <: Bound, R <: Bound, T} <: AUncertainty{T} end # TODO: `AUncertainty` should be `Domain` when supported
# abstract type AInterval{L_O <: Openness, R_O <: Openness, L, R, T} <: AUncertainty{T}  end
abstract type AInterval{LO <: LeftOpenness, RO <: RightOpenness, L <:_LeftInner, R <:_RightInner, T} <: AUncertainty{T} end # TODO: `AUncertainty` should be `Domain` when supported

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
"""
    Interval{T ≮: Interval, L <:_LeftInner{T}, R <:_RightInner{T}, LO <: LeftOpenness, RO <: RightOpenness} <: AInterval{Bound{LO, L}, Bound{RO, R}, T}

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
struct Interval{T, L <: _LeftInner{T}, R <: _RightInner{T}, LO <: LeftOpenness, RO <: RightOpenness} <: AInterval{LO, RO, L, R, T}
    left::L
    right::R

    # At least with Julia 1.13 it is impossible to constraint the type parameters adequately. Therefore constraint at least the constructed objects.
    @inline function Interval{T, L, R, LO, RO}(left::L, right::R) where {T, L <: _LeftInner{T}, R <: _RightInner{T}, LO <: LeftOpenness, RO <: RightOpenness}
        (L == NegativeInfinity && LO == LeftClosed || R == PositiveInfinity && RO == RightClosed ) && "Infinite closed bound detected" |> ArgumentError |> throw
        T <: Interval && "Elements of an `Interval` shall not be `Interval`s" |> ArgumentError |> throw
        new{T, L, R, LO, RO}(left, right)
    end
end

const RightRay{T, LO <: LeftOpenness} = Interval{T, T, PositiveInfinity, LO, RightOpen}
const LeftRay{T, RO <: RightOpenness} = Interval{T, NegativeInfinity, T, LeftOpen, RO}
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


const RegularInterval{T, LO <: LeftOpenness, RO <: RightOpenness} = Interval{T, T, T, LO, RO}
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

const OpenOpenInner{T} = OpenRegular{T}
const ClosedClosedInner{T} = ClosedRegular{T}
const OpenClosedInner{T} = OpenClosedRegular{T}
const ClosedOpenInner{T} = ClosedOpenRegular{T}

const OpenOpen{T,L,R} = Interval{T, L, R, LeftOpen, RightOpen}
const ClosedClosed{T,L,R} = Interval{T, L, R, LeftClosed, RightClosed}
const OpenClosed{T,L,R} = Interval{T, L, R, LeftOpen, RightClosed}
const ClosedOpen{T,L,R} = Interval{T, L, R, LeftClosed, RightOpen}

const LeftRight{LO <: LeftOpenness, RO <: RightOpenness} = Interval{T, L, R, LO, RO} where {T,L,R}


# If there is an official constructor accepting `(left::T, right::T) where T`, it is more specific than `(left::L, right::R) where {L,R}` and thus the former constructor needs to implement special logic for `T` being an `Interval`.

# TODO: We want to have a constructor with the single parameter `T`, as only that one should be provided when constructing it. This means we should think about whether `OpenOpen` really should be limited to be the `RegularInterval`, because from the constructor, it could be derived whether it is a `RegularInterval` or not. So we would need to define the four constructors for OpenOpen{T}, ClosedClosed{T}, OpenClosed{T} and ClosedOpen{T} all sending towards a helper.


@inline OpenOpen(left::L, right::R) where {L,R} = LeftRight{LeftOpen, RightOpen}(left, right)
@inline ClosedClosed(left::L, right::R) where {L,R} = LeftRight{LeftClosed, RightClosed}(left, right)
@inline OpenClosed(left::L, right::R) where {L,R} = LeftRight{LeftOpen, RightClosed}(left, right)
@inline ClosedOpen(left::L, right::R) where {L,R} = LeftRight{LeftClosed, RightOpen}(left, right)

# TODO: Define eltype(x::InnerInterval)

# @inline function Interval{T, L, R, LeftOpen, RightOpen}(left::L, right::R) where {T,L,R}
@inline function LeftRight{LO, RO}(left::L, right::R) where {LO <: LeftOpenness, RO <: RightOpenness, L, R}
    LT = L <: InnerInterval ? eltype(L) : L
    RT = R <: InnerInterval ? eltype(R) : R

    if L <: InnerInterval || R <: InnerInterval
        _Interval(left, right)
    elseif L == R
        Interval{L, L, L, LO, RO}(left, right)
    else
        MethodError(ClosedClosed, (L, R)) |> throw
    end
end

# @inline _Interval(left::L, right::R) where {L<:Inner{T}, R<:Inner{T}} where T = Interval{T, L, R, LeftClosed, RightClosed}(left, right)

# `Interval{LO,RO}(left::T, right::T)` is not possible with the above ordering of the type parameters.
# @inline Interval(::LO, ::RO, left::T, right::T) where {LO <: Openness, RO <: Openness, T} = Interval{T, T, T, LO, RO}(left, right)
@inline Interval(LO::Type{<:LeftOpenness}, RO::Type{<:RightOpenness}, left::T, right::T) where T = Interval{T, T, T, LO, RO}(left, right)

# Interval{T, T, T, LO, RO}(left::T, right::T) where {T, LO <: LeftOpenness, RO <: RightOpenness} = Interval{T, T, T, LO, RO}(left, right)

# @inline Interval{T, T, PositiveInfinity, LO, RightOpen}(left::T) where {T, LO <: LeftOpenness} = Interval{T, T, PositiveInfinity, LO, RightOpen}(left, +∞)

# The aliases for the different combinations use the naming scheme: `Left`[`Uncertainty`]`Right`[`Uncertainty`][`Openness`][`Openness`]`Interval`
# with the additional rules
# - `Openness` is used only once, if both `Openness` values are identical for the interval, so we have {Open, Closed, OpenClosed, ClosedOpen}.
# - `Uncertainty` uses the following values {, OpenInf, OpenSup, ClosedInf, ClosedSup, OpenInfSup, ClosedInfSup, OpenInfClosedSup, ClosedInfOpenSup, } plus either `NegativeInfinity` or `PositiveInfinity`.
# - `Uncertainty` is used only once, if both `Uncertainty` values are identical for the interval. In this case `Left` and `Right` is omitted.
# - `Left` or `Right` is omitted if the corresponding bound is not uncertain, i.e. uses `T`.
# - `Uncertainty` and `Openness` is omitted and `Interval` is changed into `Ray`, if the corresponding uncertainty is infinite. This matches the terms used in http://www.mathmatique.com/naive-set-theory/relations/intervals
# This leads to the following number of combinations per T: (2 * (1 + 4 + 4))^2 + 2 * (9 * 2) = (2 * 9)^2 + 2 * 18 = 18^2 + 36 = 324 + 36 = 360





# @inline OpenOpen(left::T, right::T) where T = Interval{T, T, T, LeftOpen, RightOpen}(left, right)
# @inline ClosedClosed(left::T, right::T) where T = Interval{T, T, T, LeftClosed, RightClosed}(left, right)
# @inline OpenClosed(left::T, right::T) where T = Interval{T, T, T, LeftOpen, RightClosed}(left, right)
# @inline ClosedOpen(left::T, right::T) where T = Interval{T, T, T, LeftClosed, RightOpen}(left, right)


# (Probably) works, but is quite specific
# @inline function ClosedClosed(left::L, right::R) where {L,R}
#     if L <: Union{CertainRay, CertainInterval} || R <: Union{CertainRay, CertainInterval}
#         _Interval(left, right)
#     elseif L == R
#         Interval{L, L, L, LeftClosed, RightClosed}(left, right)
#     else
#         MethodError(ClosedClosed, (L, R)) |> throw
#     end
# end

# @inline ClosedClosed(left::L, right::R) where {L<:LeftInner{T}, R<:RightInner{T}} where T = Interval{T, L, R, LeftClosed, RightClosed}(left, right)
# @inline ClosedClosed(left::L, right::R) where {L<:Inner{T}, R<:Inner{T}} where T = Interval{T, L, R, LeftClosed, RightClosed}(left, right)
# @inline Interval(left::L, right::R) where {L<:Inner{T}, R<:Inner{T}} where T = Interval{T, L, R, LeftClosed, RightClosed}(left, right)

@inline Greater(left::T) where T = RightRay{T, LeftOpen}(left, +∞)
@inline GreaterEqual(left::T) where T = RightRay{T, LeftClosed}(left, +∞)
@inline Less(right::T) where T = LeftRay{T, RightOpen}(-∞, right)
@inline LessEqual(right::T) where T = LeftRay{T, RightClosed}(-∞, right)

# const LeftClosedInfOpenSupRightOpenInfClosedSupOpenClosedInterval{T} = Interval{T, ClosedOpen, OpenClosed, Open, Closed}
# const LeftClosedOpenRightOpenClosedIntervalOpenClosed{T} = Interval{T, ClosedOpen, OpenClosed, Open, Closed}
# const OpenClosedIntervalClosedOpenLeftOpenClosedRight{T} = Interval{T, ClosedOpen, OpenClosed, Open, Closed}
# const ClosedOpenLeftOpenClosedRightOpenClosedInterval{T} = Interval{T, ClosedOpen, OpenClosed, Open, Closed}
const ClosedOpenLeft_OpenClosedRight_OpenClosedInterval{T} = Interval{T, ClosedOpen, OpenClosed, LeftOpen, RightClosed}

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

Base.print(io::IO, x::AInterval{LO, RO}) where {LO, RO} = print(io, LO, x.left, ", ", x.right, RO)
Base.print(io::IO, x::Greater) = print(io, ">", x.left)
Base.print(io::IO, x::GreaterEqual) = print(io, "≥", x.left)
Base.print(io::IO, x::Less) = print(io, "<", x.right)
Base.print(io::IO, x::LessEqual) = print(io, "≤", x.right)

Base.show(io::IO, ::MIME"text/plain", x::AInterval) = print(io, x)

function Base.tryparse(::Type{<:CertainInterval{T}}, str::AbstractString) where T
    # We want to do `match(r"([([])\s*([^,]+)\s*,\s*([^,]+)\s*([)\]])", s)`, but allocation-free

    s = strip(str)

    @⊤ ncodeunits(s) >= ncodeunits("(1,2)")
    @∃ left_openness = tryparse(LeftOpenness, s |> first)
    @∃ right_openness = tryparse(RightOpenness, s |> last)

    return tryparse_inner(CertainInterval{T}, @view(s[2:end-1]), left_openness, right_openness) # Indexing is correct as the first and the last are ASCII
end

@inline function tryparse_inner(::Type{<:CertainInterval{T}}, s::AbstractString, left_openness::LeftOpenness, right_openness::RightOpenness) where T
    @∃ n = findnext(',', s, 1)
    @∄ findnext(',', s, n+1) # +1 is correct, as the comma is ASCII

    @∃ left = tryparse(T, @view s[1 : prevind(s, n)])
    @∃ right = tryparse(T, @view s[n+1 : end])

    # return Interval(left_openness, right_openness, left, right)::CertainInterval{T} # Julia should be able to efficiently handle this
    # return Interval{T, T, T, left_openness |> typeof, right_openness |> typeof}(left, right) # or at least handle this
    isclosed(left_openness) && isclosed(right_openness) && return ClosedClosed{T}(left, right)
    isopen(left_openness) && isopen(right_openness) && return OpenOpen{T}(left, right)
    isclosed(left_openness) && isopen(right_openness) && return ClosedOpen{T}(left, right)
    return OpenClosed{T}(left, right) # or at least efficiently handle this – but it can't with Julia 1.13, although this is the least inefficient
end

Base.tryparse(::Type{<:Greater{T}},      s::AbstractString) where T = s[1] == '>' ? tryparse(T, @view s[1+ncodeunits('>') : end]) |> Greater      : nothing
Base.tryparse(::Type{<:GreaterEqual{T}}, s::AbstractString) where T = s[1] == '≥' ? tryparse(T, @view s[1+ncodeunits('≥') : end]) |> GreaterEqual : nothing
Base.tryparse(::Type{<:Less{T}},         s::AbstractString) where T = s[1] == '<' ? tryparse(T, @view s[1+ncodeunits('<') : end]) |> Less         : nothing
Base.tryparse(::Type{<:LessEqual{T}},    s::AbstractString) where T = s[1] == '≤' ? tryparse(T, @view s[1+ncodeunits('≤') : end]) |> LessEqual    : nothing

function Base.tryparse(::Type{<:Comparison{T}}, s::AbstractString) where T
    @∃⏎ tryparse(Greater{T}, s)
    @∃⏎ tryparse(GreaterEqual{T}, s)
    @∃⏎ tryparse(Less{T}, s)
    @∃⏎ tryparse(LessEqual{T}, s)
end

# function Base.parse(::Type{<:AInterval{T}}, s::AbstractString) where T # wrong parameter order in AInterval
function Base.tryparse(::Type{<:Interval{T}}, str::AbstractString) where T
    s = strip(str)

    @∃⏎ tryparse(Comparison{T}, s)

    @⊤ ncodeunits(s) >= ncodeunits("(1,2)")
    @∃ left_openness = tryparse(LeftOpenness, s |> first)
    @∃ right_openness = tryparse(RightOpenness, s |> last)

    is_certain_left = tryparse(LeftOpenness, s[2]) |> isnothing
    is_certain_right = tryparse(RightOpenness, s[prevind(s, lastindex(s))]) |> isnothing

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
