# `Base.uniontypes` stops at an outer `where`, so strip all of them and put them back on each member.
unionmembers(U) = Base.uniontypes(U)
unionmembers(U::UnionAll) = U |> Base.unwrap_unionall |> Base.uniontypes .|> Base.Fix2(Base.rewrap_unionall, U)

# `Base.uniontypes` allocates a mutable `Vector`, so the compiler proves neither `:consistent` nor `:terminates` and refuses to fold. The result is an interned type, so asserting it is sound.
"""
    typeunion(U; whole::Bool = false)

The type objects of the members of the union `U`, so `Union{Type{Int}, Type{Float64}}` for `Union{Int, Float64}`, with `whole` adding the type object of `U` itself. Needed wherever `Type{<:U}` is too wide, as that also covers `Union{}` and every sub-union of `U`.
"""
Base.@assume_effects :foldable typeunion(U; whole::Bool = false) = whole ? Union{Core.Typeof(U), typeunion(U)} : Union{(U |> unionmembers .|> Core.Typeof)...}

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

Base.tryparse(O::typeunion(Openness), c::AbstractChar) = c == Char(O) ? O() : nothing
Base.tryparse(::Type{LeftOpenness}, c::AbstractChar) = @∃⏎ tryparse(LeftOpen, c) tryparse(LeftClosed, c)
Base.tryparse(::Type{RightOpenness}, c::AbstractChar) = @∃⏎ tryparse(RightOpen, c) tryparse(RightClosed, c)

Base.print(io::IO, O::typeunion(Openness)) = print(io, O |> Char)
Base.findfirst(O::Union{typeunion(LeftOpenness; whole = true), typeunion(RightOpenness; whole = true)}, s::AbstractString) = findfirst(O |> chars |> in, s)

Base.Char(::Type{LeftOpen}) = '('
Base.Char(::Type{LeftClosed}) = '['
Base.Char(::Type{RightOpen}) = ')'
Base.Char(::Type{RightClosed}) = ']'

chars(::typeunion(LeftOpenness; whole = true)) = (LeftOpen, LeftClosed) .|> Char
chars(::typeunion(RightOpenness; whole = true)) = (RightOpen, RightClosed) .|> Char