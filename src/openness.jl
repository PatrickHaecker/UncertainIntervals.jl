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

Base.tryparse(O::Type{<:Openness}, c::AbstractChar) = c == Char(O) ? O() : nothing
Base.tryparse(::Type{LeftOpenness}, c::AbstractChar) = @∃⏎ tryparse(LeftOpen, c) tryparse(LeftClosed, c)
Base.tryparse(::Type{RightOpenness}, c::AbstractChar) = @∃⏎ tryparse(RightOpen, c) tryparse(RightClosed, c)

Base.print(io::IO, O::Type{<:Openness}) = print(io, O |> Char)
Base.findfirst(O::Type{<:Openness}, s::AbstractString) = findfirst(O |> chars |> in, s)

Base.Char(::Type{LeftOpen}) = '('
Base.Char(::Type{LeftClosed}) = '['
Base.Char(::Type{RightOpen}) = ')'
Base.Char(::Type{RightClosed}) = ']'

chars(::Type{<:LeftOpenness}) = (LeftOpen, LeftClosed) .|> Char
chars(::Type{<:RightOpenness}) = (RightOpen, RightClosed) .|> Char