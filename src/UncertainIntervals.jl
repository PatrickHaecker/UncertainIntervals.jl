module UncertainIntervals

using Infinities: NegativeInfinity, PositiveInfinity, RealInfinity, ∞

include("exceptional.jl")
include("openness.jl")
include("interval.jl")
include("parsing.jl")

export @i_str, Interval, AInterval, OpenOpen, ClosedClosed, OpenClosed, ClosedOpen, Line, Less, LessEqual, Greater, GreaterEqual, Comparison
export LeftOpen, LeftClosed, RightOpen, RightClosed, LeftOpenness, RightOpenness, Openness
export isdiscrete, successor, predecessor, normalize, simplify

VERSION >= v"1.11" && "public isopen, isclosed" |> Meta.parse |> eval

end
