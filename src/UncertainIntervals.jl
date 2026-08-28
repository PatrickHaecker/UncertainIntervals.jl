module UncertainIntervals

using Infinities: NegativeInfinity, PositiveInfinity, RealInfinity, ∞

include("exceptional.jl")
include("openness.jl")
include("interval.jl")
include("parsing.jl")

end
