module UncertainIntervals

using Exceptional: @∃, @⏎∃, @⊤, @⊥, @⏎⊤, @■
using Infinities: NegativeInfinity, PositiveInfinity, RealInfinity, ∞

include("openness.jl")
include("interval.jl")
include("hashing.jl")
include("parsing.jl")

export @i_str, Interval, AInterval, OpenOpen, ClosedClosed, OpenClosed, ClosedOpen, Line, Less, LessEqual, Greater, GreaterEqual, Comparison
export LeftOpen, LeftClosed, RightOpen, RightClosed, LeftOpenness, RightOpenness, Openness
export isdiscrete, successor, predecessor, normalize, simplify
# Re-exported, as a bound is written with them.
export ∞, NegativeInfinity, PositiveInfinity

VERSION >= v"1.11" && "public isopen, isclosed" |> Meta.parse |> eval

end
