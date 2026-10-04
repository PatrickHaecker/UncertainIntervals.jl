using Test
using UseAll
using Dates
using Infinities
using Aqua, JET

@useall UncertainIntervals

# Comparing against an empty vector rather than asking `isempty` so that a failure names the offending pair.
@testset "Method Ambiguities" begin
    @test detect_ambiguities(UncertainIntervals) == []
end

@testset "Aqua" begin
    # `Inner{T}` is a type of this package, and `LeftInner{T}` and `RightInner{T}` add an infinity to it, which the check reads as another package's.
    Aqua.test_all(UncertainIntervals; unbound_args = false,
        piracies = (; treat_as_own = [Inner, NegativeInfinity, PositiveInfinity]))

    # Julia does solve `T` out of `Type{Inner{T}}`, which the check cannot see. Anything else unbound still fails.
    bounds = (which(tryparse, Tuple{Type{Inner{Int}}, String}),
              which(tryparse, Tuple{Type{LeftInner{Int}}, String}),
              which(tryparse, Tuple{Type{RightInner{Int}}, String}),
              which(parse, Tuple{Type{Inner{Int}}, String}),
              which(parse, Tuple{Type{LeftInner{Int}}, String}),
              which(parse, Tuple{Type{RightInner{Int}}, String}))
    @test issubset(Aqua.detect_unbound_args_recursively(UncertainIntervals), bounds)
end

@testset "JET" begin
    JET.test_package(UncertainIntervals)
end

# Test basic interval construction
@testset "Basic Interval Construction" begin
    # Test certain interval
    interval = ClosedClosed(1.0, 2.0)
    @test interval.left == 1.0
    @test interval.right == 2.0
    @test interval isa Interval{Float64}
end

@testset "Advanced Interval Construction" begin
    @test ClosedOpen(4, +∞) isa Interval{Int64, LeftClosed, RightOpen, Int64, PositiveInfinity}
    @test OpenOpen{Int}(4, +∞) isa Interval{Int64, LeftOpen, RightOpen, Int64, PositiveInfinity}
    @test isequal(Interval{Int, LeftOpen, RightClosed}(-4.0, 2), OpenClosed(-4, 2))
    @test isequal(Line{Int}(), OpenOpen{Int}(-∞, +∞))
    @test sprint(print, Line{Float64}()) == "(-∞, +∞)"

    # A bound at infinity has to be open, while the extremes of the element type are ordinary values.
    @test_throws ArgumentError ClosedOpen(-∞, 5)
    @test_throws ArgumentError OpenClosed(4, +∞)
    @test ClosedClosed(typemin(Int), typemax(Int)) isa Interval{Int, LeftClosed, RightClosed, Int, Int}
    @test ClosedClosed(-Inf, Inf) isa Interval{Float64, LeftClosed, RightClosed, Float64, Float64}

    # An infinity names no element type, in a bound as much as in an interval.
    @test_throws ArgumentError OpenOpen(+∞, +∞)
    @test_throws ArgumentError OpenOpen(-∞, -∞)
    @test_throws ArgumentError Line{PositiveInfinity}()
    @test_throws ArgumentError i"[(∞, ∞), 5]"
end

@testset "Conversion" begin
    @test isequal(convert(ClosedOpen{Int}, ClosedOpen(1.0, 2.0)), ClosedOpen(1, 2)) # the element type alone
    @test isequal(convert(ClosedClosed{Int}, ClosedClosed(1.0, 2.0)), ClosedClosed(1, 2))

    # A discrete element type spells the same members with either openness, one value further out.
    @test isequal(convert(ClosedOpen{Int}, ClosedClosed(1, 2)), ClosedOpen(1, 3))
    @test isequal(convert(OpenOpen{Int}, ClosedClosed(1, 2)), OpenOpen(0, 3))
    @test isequal(convert(ClosedClosed{Int}, OpenOpen(0, 3)), ClosedClosed(1, 2))
    @test isequal(convert(OpenOpen{Int}, GreaterEqual(4)), Greater(3))
    @test convert(ClosedOpen{Int}, ClosedClosed(1, 2)) == ClosedClosed(1, 2)

    # The openness of a dense interval cannot be changed.
    @test_throws InexactError convert(ClosedOpen{Float64}, ClosedClosed(1.0, 2.0))
    @test_throws InexactError convert(ClosedOpen{Int}, ClosedClosed(1, typemax(Int)))
    @test_throws InexactError convert(OpenOpen{Int}, ClosedClosed(typemin(Int), 2))
end

# Test interval parsing
@testset "Parse Certain Intervals" begin
    # `isequal` rather than `==`, as the openness is part of what parsing has to get right.
    @test isequal(tryparse(CertainInterval{Int}, "(1, 2)"), OpenOpen(1, 2))
    @test isequal(tryparse(CertainInterval{Int}, "(1, 2]"), OpenClosed(1, 2))
    @test isequal(tryparse(CertainInterval{Int}, "[1, 2)"), ClosedOpen(1, 2))
    @test isequal(tryparse(CertainInterval{Int}, "[1, 2]"), ClosedClosed(1, 2))

    # A float infinity and a `NaN` are values the element type holds, so they parse like any other.
    @test isequal(tryparse(Interval{Float64}, "[-Inf, Inf]"), ClosedClosed(-Inf, Inf))
    @test isequal(tryparse(Interval{Float64}, "[NaN, NaN]"), ClosedClosed(NaN, NaN))
end

@testset "Parse Certain Intervals with spaces" begin
    @test isequal(tryparse(CertainInterval{Int}, "[1,2]"), ClosedClosed(1, 2))
    @test isequal(tryparse(CertainInterval{Int}, "[  1  ,  2  ]"), ClosedClosed(1, 2))
    @test isequal(tryparse(CertainInterval{Int}, "  [  1  ,  2  ]  "), ClosedClosed(1, 2))
end
@testset "Parse Certain Intervals with a fixed openness" begin
    # `===` also pins the type down to the one asked for.
    @test tryparse(OpenRegular{Int}, "(1, 2)") === OpenOpen(1, 2)
    @test tryparse(OpenClosedRegular{Int}, "(1, 2]") === OpenClosed(1, 2)
    @test tryparse(ClosedOpenRegular{Int}, "[1, 2)") === ClosedOpen(1, 2)
    @test tryparse(ClosedRegular{Int}, "[1, 2]") === ClosedClosed(1, 2)

    # Any other openness is a parse failure rather than a differently typed interval.
    @test isnothing(tryparse(OpenRegular{Int}, "[1, 2)"))
    @test isnothing(tryparse(OpenRegular{Int}, "(1, 2]"))
    @test isnothing(tryparse(OpenRegular{Int}, "[1, 2]"))
    @test isnothing(tryparse(ClosedRegular{Int}, "(1, 2)"))
    @test isnothing(tryparse(ClosedOpenRegular{Int}, "(1, 2]"))
    @test isnothing(tryparse(OpenClosedRegular{Int}, "[1, 2)"))

    @test isnothing(tryparse(ClosedOpenRegular{Int}, "no interval"))
    @test isnothing(tryparse(ClosedOpenRegular{Int}, "[x, 2)"))
    @test isnothing(tryparse(ClosedRegular{Int}, "[1, 2, 3]")) # two bounds take one comma
end
@testset "Parse Rays" begin
    @test isequal(tryparse(Interval{Int}, ">4"), Greater(4))
    @test isequal(tryparse(Interval{Int}, " < 5 "), Less(5))
    @test isequal(tryparse(Interval{Int}, "≥12"), GreaterEqual(12))
    @test isequal(tryparse(Interval{Float64}, "≤2.5"), LessEqual(2.5))

    @test isequal(tryparse(Interval{Int}, ">=12"), GreaterEqual(12))
    @test isequal(tryparse(Interval{Float64}, "<=2.5"), LessEqual(2.5))
    @test isequal(tryparse(Interval{Int}, "  >= 4 "), GreaterEqual(4))

    # A bound which does not parse must fail the whole ray, not become its element.
    @test isnothing(tryparse(Interval{Int}, "<x"))
    @test isnothing(tryparse(Interval{Int}, ">=x"))
    @test isnothing(tryparse(Interval{Int}, ">"))
end

@testset "Parse Uncertain Intervals" begin
    @test isequal(tryparse(Interval{Int}, "[2, >4]"), ClosedClosed(2, OpenOpen(4, +∞)))
    @test isequal(tryparse(Interval{Float32}, "(≥2.0, 5.2)"), OpenOpen(ClosedOpen(2f0, +∞), 5.2f0))
    @test isequal(tryparse(Interval{Float32}, "(≥2, 5.2)"), OpenOpen(ClosedOpen(2f0, +∞), 5.2f0))
    @test isequal(tryparse(Interval{Float64}, "([-3.4, -2.87], ≥-1.4]"), OpenClosed(ClosedClosed(-3.4, -2.87), ClosedOpen(-1.4, +∞)))

    @test_throws ArgumentError OpenOpen(-∞, +∞)
    @test isequal(tryparse(Interval{Int32}, "(-∞, ∞)"), OpenOpen{Int32}(-∞, +∞))

    # A bound takes the element type from the interval it belongs to, so it can be the line itself.
    @test isequal(tryparse(Interval{Int}, "[(-∞, +∞), 5]"), ClosedClosed(Line{Int}(), 5))
    @test sprint(print, ClosedClosed(Line{Int}(), 5)) == "[(-∞, +∞), 5]"
    @test ismissing(isempty(ClosedClosed(Line{Int}(), 5)))
    @test isnothing(tryparse(Interval{Int}, "[(-∞, +∞], 5]")) # an infinite bound stays open
end

@testset "Parse" begin
    # `parse` takes its spellings from `tryparse` and turns a failure into an exception.
    @test isequal(parse(Interval{Int}, "(2, 5)"), OpenOpen(2, 5))
    @test isequal(parse(Interval{Int}, "[2, >4]"), ClosedClosed(2, Greater(4)))
    @test parse(ClosedRegular{Int}, "[1, 2]") === ClosedClosed(1, 2)
    @test parse(Inner{Int}, "5") === 5
    @test parse(RightInner{Int}, "+∞") === +∞
    @test_throws ArgumentError parse(Interval{Int}, "[1, 2, 3]")
    @test_throws ArgumentError parse(OpenRegular{Int}, "[1, 2]")
    @test_throws ArgumentError parse(LeftInner{Int}, "+∞")

    # Only `String`s and their substrings are read, anything else converts first.
    @test parse(ClosedRegular{Int}, SubString("x[1, 2]", 2)) === ClosedClosed(1, 2)
    @test_throws MethodError tryparse(Interval{Int}, Test.GenericString("[1, 2]"))
    @test parse(ClosedRegular{Int}, String(Test.GenericString("[1, 2]"))) === ClosedClosed(1, 2)

    # A single bracket names an openness, where the failure is the same one.
    @test parse(LeftOpenness, '(') === LeftOpen()
    @test parse(RightClosed, ']') === RightClosed()
    @test_throws ArgumentError parse(LeftOpenness, ']')
    @test_throws ArgumentError parse(RightClosed, ')')
end

@testset "Printing" begin
    @test sprint(print, ClosedOpen(2.0, 5.0)) == "[2.0, 5.0)"
end

# A discrete element type whose values do not all compare, which no `Integer` offers.
struct Fuzzy
    v::Float64
end
Base.isless(a::Fuzzy, b::Fuzzy) = isless(a.v, b.v)
Base.:(<=)(a::Fuzzy, b::Fuzzy) = a.v <= b.v
Base.:(==)(a::Fuzzy, b::Fuzzy) = a.v == b.v
UncertainIntervals.successor(x::Fuzzy) = Fuzzy(nextfloat(x.v))
UncertainIntervals.predecessor(x::Fuzzy) = Fuzzy(prevfloat(x.v))

@testset "Emptiness" begin
    @test !isempty(i"[3, 5]")
    @test !isempty(i"[5, 5]")
    @test isempty(i"(5, 5)")
    @test isempty(i"[5, 5)")
    @test isempty(i"(5, 5]")
    @test !isempty(i"≤2.5")

    # An uncertain bound can still decide it.
    @test isempty(i"[(3, 5), 1]")
    @test !isempty(i"[(1, 3), 5]")
    @test isempty(i"[(1, 3), 1]")
    @test isempty(i"([1, 3], 1)")

    @test ismissing(isempty(i"[(1.0, 3.0), 2.0]"))
    @test ismissing(isempty(i"[[1, 3], 1]"))
    @test ismissing(isempty(i"[≤9, 5]"))
    @test ismissing(isempty(i"(≥1, 5]")) # an open side steps up from the bound's own `+∞`
    @test ismissing(isempty(i"[5, ≤9)"))

    # A bound with no value to take leaves the interval without an endpoint.
    @test isempty(i"[(2.0, 2.0), 5.0]")
    @test isempty(i"[5.0, (7.0, 7.0)]")
    @test isempty(i"[(2, 2), 5]")

    # A discrete `T` turns every open bound into the closed one a step further in.
    @test isempty(i"(1, 2)")
    @test !isempty(i"(1.0, 2.0)")
    @test !isempty(i"(1, 3)")
    @test !isempty(i"[(1, 3), 2]")
    @test isempty(i"((0, 2), 2)")

    # A bound open at an extreme demands a value the type cannot hold.
    @test isempty(i"(typemax(Int), typemax(Int))")
    @test isempty(i"(typemax(Int), typemax(Int)]")
    @test isempty(i"[typemin(Int), typemin(Int))")
    @test !isempty(i"[typemax(Int), typemax(Int)]")
    @test !isempty(i"(typemax(Int) - 1, typemax(Int)]")
    @test isempty(i"(true, true)")
    @test isempty(i"(big(1), big(2))")
    @test !isempty(i"(big(1), big(3))")

    # The same bound one step away from the extreme leaves the answer open, so the extreme has to as well.
    @test ismissing(isempty(i"([1, 9], 5]"))
    @test ismissing(isempty(i"([1, typemax(Int)], 5]"))
    @test ismissing(isempty(i"[3, [-9, 4])"))
    @test ismissing(isempty(i"[3, [typemin(Int), 4])"))

    # A bound whose own open limit steps off the type holds no value, so no endpoint is left to take.
    @test isempty(ClosedClosed(OpenOpen(1, typemin(Int)), 9))
    @test isempty(ClosedClosed(1, OpenOpen(typemax(Int), 9)))
    @test isempty(OpenOpen(ClosedClosed(3, typemax(Int)), ClosedClosed(9, 5))) # the other bound is empty

    # An extreme of the element type meeting a bound at infinity.
    @test !isempty(i"[typemin(Int), typemax(Int)]")
    @test !isempty(i"(typemin(Int), typemax(Int))")
    @test !isempty(i"(-∞, typemin(Int)]")
    @test isempty(i"(-∞, typemin(Int))")
    @test !isempty(i"[typemax(Int), +∞)")
    @test isempty(i"(typemax(Int), +∞)")
    @test ismissing(isempty(i"[[typemin(Int), typemax(Int)], 5]"))
    @test !isempty(i"[≥typemax(Int), typemax(Int)]") # the bound holds `typemax(Int)` and nothing else

    # A float infinity is a value of its type rather than a bound at infinity.
    @test !isempty(i"[-Inf, Inf]")
    @test !isempty(i"[Inf, Inf]")
    @test isempty(i"(-Inf, -Inf)")

    # `Bool` holds exactly the two values a step runs between.
    @test isempty(i"(false, true)")
    @test !isempty(i"(false, true]")
    @test !isempty(i"[false, true)")

    # A bound no value compares with holds none of them.
    @test isempty(i"(NaN, 1.0)")
    @test isempty(i"[1.0, NaN]")
    @test isempty(i"[NaN, NaN]")

    # Only a discrete element type reaches the other branch, where an incomparable limit used to throw.
    @test isempty(ClosedClosed(Fuzzy(NaN), Fuzzy(NaN)))
    @test isempty(OpenOpen(Fuzzy(NaN), Fuzzy(1.0)))      # here the limits are stepped first
    @test !isempty(ClosedClosed(Fuzzy(1.0), Fuzzy(2.0))) # so neither of the two passes vacuously

    # Certain bounds decide, so a `Bool` reaches the caller and stays usable as a condition.
    @test (@inferred isempty(i"[5, 3]")) === true
    @test (@inferred isempty(i">4")) === false
    @test (@inferred isempty(Line{Int}())) === false
end

@testset "Membership" begin
    @test 5 ∈ i"[1, 9]"
    @test 1 ∈ i"[1, 9]"
    @test !(0 ∈ i"[1, 9]")
    @test !(1 ∈ i"(1, 9)")
    @test 2 ∈ i"(1, 9)"
    @test 5 ∈ i">4"
    @test !(4 ∈ i">4")
    @test 0 ∈ Line{Int}()

    # Every endpoint the uncertainty allows has to agree.
    @test ismissing(5 ∈ i"[(1, 9), 20]")
    @test 9 ∈ i"[(1, 9), 20]"
    @test !(1 ∈ i"[(1, 9), 20]")
    @test !(21 ∈ i"[(1, 9), 20]")

    # An empty interval holds no value at all.
    @test !(5 ∈ i"[5, 3]")
    @test !(5 ∈ i"(5, 5)")
    @test !(3 ∈ i"[(2, 2), 5]")
    @test !(5 ∈ i"(typemax(Int), +∞)")

    # A dense element type reads the limits with their openness in place of stepping them.
    @test 5.0 ∈ i"[1.0, 9.0]"
    @test !(1.0 ∈ i"(1.0, 9.0)")
    @test !(NaN ∈ i"[1.0, 9.0]") # a value the order relates to nothing is a member of nothing
    # `NaN` compares false against an infinite limit too, so it stays out even between two of them.
    @test !(NaN ∈ i"≥1.0")
    @test !(NaN ∈ Line{Float64}())
    @test 5.0 ∈ i"[(1.0, 3.0), 7.0]"
    @test !(0.5 ∈ i"[(1.0, 3.0), 7.0]")
    @test ismissing(2.0 ∈ i"[(1.0, 3.0), 7.0]")
    # Non-empty, and still no value belongs to every interval its endpoints allow.
    @test ismissing(2.0 ∈ i"((0.0, 2.0), [2.0, 3.0])")

    # A limit that steps beyond the element type leaves the answer open, as it does for `isempty`.
    @test ismissing(5 ∈ i"([1, typemax(Int)], typemax(Int)]")
    @test !(5 ∈ ClosedClosed(OpenOpen(1, typemin(Int)), 9))
    @test !(5 ∈ ClosedClosed(1, OpenOpen(typemax(Int), 9)))
    @test typemax(Int) ∈ i"[typemax(Int), +∞)"

    # Certain bounds decide, so a `Bool` reaches the caller.
    @test (@inferred 5 ∈ i"[1, 9]") === true
    @test (@inferred 5.0 ∈ i"(1.0, 9.0)") === true

    # An unknown value, as in `Base`, is only ruled out by an interval that certainly holds nothing.
    @test ismissing(missing ∈ i"[1, 9]")
    @test ismissing(missing ∈ i"[1.0, 9.0]")
    @test ismissing(missing ∈ i"[(1, 9), 20]")
    @test ismissing(missing ∈ i"[[1, 9], 5]") # possibly empty
    @test !(missing ∈ i"[5, 3]")
    @test !(missing ∈ i"[(2, 2), 5]")
end

@testset "Subset" begin
    @test i"[1, 2]" ⊆ i"[1, 3]"
    @test i"[1, 2]" ⊆ i"[1, 2]"
    @test i"[1, 3]" ⊈ i"[1, 2]"
    @test i"(1, 9)" ⊆ i"[1, 9]"
    @test i"[1, 9]" ⊈ i"(1, 9)"
    @test i"[1, 2]" ⊆ Line{Int}()
    @test Line{Int}() ⊈ i"[1, 2]"
    @test i"[1, 2]" ⊇ i"[2, 2]" # `⊇` is `⊆` with the arguments swapped
    @test i"[1, 2]" ⊉ i"[1, 3]" # and `⊉` negates that one
    @test ismissing(i"[1, 2]" ⊈ i"[[1, 3], 7]") # a negation leaves an undecided answer undecided

    # A discrete element type reads both spellings of a limit as one, so `==` and `⊆` agree.
    @test i"(3, 7)" ⊆ i"[4, 6]"
    @test i"[4, 6]" ⊆ i"(3, 7)"
    @test i"≥5" ⊆ i">4"
    @test i">4" ⊆ i"≥5"

    # Every pair of endpoints the two can take has to agree.
    @test ismissing(i"[1, 2]" ⊆ i"[[1, 3], 7]") # a left endpoint of 2 keeps 1 out, one of 1 does not
    @test ismissing(i"[2, 3]" ⊆ i"[[1, 3], 7]")
    @test i"[4, 5]" ⊆ i"[[1, 3], 7]"
    @test i"[0, 5]" ⊈ i"[[1, 3], 7]"
    @test ismissing(i"[2, >4]" ⊆ i"[1, 9]") # a right endpoint above 9 leaves `y`
    @test i"[2, >4]" ⊆ Line{Int}()

    # Over a discrete element type an open bound can pin the endpoint, which decides the answer.
    @test i"[1, 2]" ⊈ i"[(1, 3), 7]" # `(1, 3)` leaves the left endpoint no choice but 2
    @test i"[2, 2]" ⊆ i"[(1, 3), 7]"

    # An interval that could be empty is a subset wherever its non-empty readings are.
    @test i"[[1, 9], 5]" ⊆ i"[1, 5]"
    @test ismissing(i"[[1, 9], 5]" ⊆ i"[3, 5]") # a left endpoint of 1 leaves `y`
    @test ismissing(i"[[1, 9], 5]" ⊆ i"[6, 9]") # only the empty readings fit

    # An empty interval asks nothing of the other one, and takes nothing in.
    @test i"[5, 3]" ⊆ i"[1, 2]"
    @test i"(5, 5)" ⊆ i"[5, 3]"
    @test i"[1, 2]" ⊈ i"[5, 3]"
    @test i"[1, 2]" ⊈ i"[(2, 2), 5]"     # a bound with no value to take
    @test i"[3.0, 4.0]" ⊈ i"[(2.0, 2.0), 5.0]"
    @test i"[1.0, 2.0]" ⊈ i"[NaN, NaN]"  # `NaN` compares with nothing, so the interval holds nothing
    @test i"[NaN, NaN]" ⊆ i"[1.0, 2.0]"

    # A dense element type reads the limits with their openness in place of stepping them.
    @test i"(1.0, 9.0)" ⊆ i"[1.0, 9.0]"
    @test i"[1.0, 9.0]" ⊈ i"(1.0, 9.0)"
    @test i"[4.0, 5.0]" ⊆ i"[(1.0, 3.0), 7.0]"
    @test i"[1.0, 2.0]" ⊈ i"[(1.0, 3.0), 7.0]" # every left endpoint stays above 1.0
    @test ismissing(i"[2.0, 2.5]" ⊆ i"[(1.0, 3.0), 7.0]")

    # A limit at infinity names the extreme of a discrete element type, so the two spellings contain each other.
    @test i">5" ⊆ i"[6, typemax(Int)]"
    @test i"[6, typemax(Int)]" ⊆ i">5"
    @test i"((1, typemax(Int)], typemax(Int)]" ⊆ Line{Int}()
    @test i"[1, 2]" ⊈ i"([1, typemax(Int)], typemax(Int)]" # every left endpoint of `y` sits above 1
    @test i"[big(1), big(2)]" ⊆ i"[big(0), big(9)]"           # a type without extremes keeps its infinities

    # What separates the two spellings is where the extreme of the element type sits: `Inf` is order-equal to `+∞`, so a bound closed at it holds a member the ray leaves out, while `typemax(Int)` lies below the limit, which leaves nothing between the two. `⊆` pins that down where `==` only keeps them apart.
    @test i"≥0.0" ⊆ i"[0.0, Inf]"
    @test i"[0.0, Inf]" ⊈ i"≥0.0"
    @test i"[0.0, Inf)" ⊆ i"≥0.0"
    @test i"≥0.0" ⊆ i"[0.0, Inf)"

    # Certain bounds decide, so a `Bool` reaches the caller.
    @test (@inferred i"[1, 2]" ⊆ i"[1, 3]") === true
    @test (@inferred i"[1.5, 2.0]" ⊆ i"(1.0, 3.0)") === true
    @test (@inferred i">4" ⊆ Line{Int}()) === true
end

@testset "Normalization" begin
    @test isequal(normalize(i"(3, 7)"), i"[4, 6]")
    @test isequal(normalize(i"[4, 6]"), i"[4, 6]")
    @test isequal(normalize(i"[2, 5)"), i"[2, 4]")
    @test isequal(normalize(i">4"), i"≥5")
    @test isequal(normalize(i"(1.0, 2.0)"), i"(1.0, 2.0)") # a dense element type is already canonical
    @test isequal(normalize(Line{Int}()), Line{Int}())      # a bound at infinity stays open
    # An uncertainty is canonical too, keeping its shape so that the result type follows from the argument type.
    @test isequal(normalize(i"[(1, 3), 7]"), i"[[2, 2], 7]")
    @test isequal(normalize(i"((1, 3), 7]"), i"[[3, 3], 7]")
    @test isequal(normalize(i"[(1, 5), (2, 6)]"), i"[[2, 4], [3, 5]]")
    @test isequal(normalize(i"(≥1, 5]"), i"[≥2, 5]") # the bound's own limit at infinity stays open
    @test isequal(normalize(i"[5, ≤9)"), i"[5, ≤8]")
    @test (@inferred normalize(i"[(1, 3), 7]")) isa Interval

    # A step stays inside the element type, which `Bool` arithmetic does not do on its own.
    @test isequal(normalize(i"(false, true]"), i"[true, true]")
    @test isequal(normalize(i"[false, true)"), i"[false, false]")
    @test isequal(normalize(i"[false, true]"), i"[false, true]")

    # An extreme of the element type, alone and against a bound at infinity.
    @test isequal(normalize(i"[typemin(Int), typemax(Int)]"), i"[typemin(Int), typemax(Int)]")
    @test isequal(normalize(i"(typemin(Int), typemax(Int))"), i"[typemin(Int) + 1, typemax(Int) - 1]")
    @test isequal(normalize(i"(-∞, typemax(Int))"), i"≤typemax(Int) - 1")
    @test isequal(normalize(i"(typemin(Int), +∞)"), i"≥typemin(Int) + 1")
    @test isequal(normalize(i"(-∞, typemin(Int)]"), i"≤typemin(Int)")
    @test isequal(normalize(i"(false, true)"), i"[true, false]") # empty, so any shape will do

    # Where the widest step leaves the element type, every endpoint does, so no member is left to keep.
    @test_throws ArgumentError normalize(i"(typemax(Int), +∞)")
    @test_throws ArgumentError normalize(i"(true, true)")

    # A narrowest step that leaves the element type stalls at the extreme, which keeps every possible member set.
    @test isequal(normalize(i"([1, typemax(Int)], 5]"), i"[[2, typemax(Int)], 5]")
    @test isequal(normalize(i"[3, [typemin(Int), 4])"), i"[3, [typemin(Int), 3]]")
    @test_throws ArgumentError normalize(i"([1, typemax(Int)], typemax(Int)]") # here no kept endpoint empties `x`

    # A dense element type keeps every value, including the ones no order relates.
    @test isequal(normalize(i"(-Inf, Inf)"), i"(-Inf, Inf)")
    @test isequal(normalize(i"[NaN, NaN]"), i"[NaN, NaN]")
end

@testset "Simplification" begin
    # `simplify` goes on to drop an uncertainty that is down to a single value.
    @test isequal(simplify(i"[(1, 3), 7]"), i"[2, 7]")
    @test isequal(simplify(i"((1, 3), 7]"), i"[3, 7]")
    @test isequal(simplify(i"[(1, 5), (2, 6)]"), i"[[2, 4], [3, 5]]") # neither bound is down to a single value
    @test isequal(simplify(i"(3, 7)"), i"[4, 6]")
    @test isequal(simplify(i"(1.0, 2.0)"), i"(1.0, 2.0)")
    @test isequal(simplify(Line{Int}()), Line{Int}())

    # A dense element type has no limits to move, but a bound down to one value collapses all the same.
    @test isequal(simplify(i"[[2.0, 2.0], 5.0]"), i"[2.0, 5.0]")
    @test isequal(simplify(i"([2.0, 2.0], 5.0)"), i"(2.0, 5.0)")
    @test isequal(simplify(i"[[2.0, 2.0], [5.0, 5.0]]"), i"[2.0, 5.0]")
    @test isequal(simplify(i"[(1.0, 3.0), 7.0]"), i"[(1.0, 3.0), 7.0]")
    @test isequal(simplify(i"[≥3.0, 9.0]"), i"[≥3.0, 9.0]")

    # The extremes take the same limits as `normalize`, so they collapse alike.
    @test isequal(simplify(i"(typemin(Int), typemax(Int))"), i"[typemin(Int) + 1, typemax(Int) - 1]")
    @test isequal(simplify(i"[[typemax(Int), typemax(Int)], 5]"), i"[typemax(Int), 5]")
    @test isequal(simplify(i"[[Inf, Inf], 5.0]"), i"[Inf, 5.0]")
    @test isequal(simplify(i"[-Inf, Inf]"), i"[-Inf, Inf]")
    @test isequal(simplify(i"([1, typemax(Int)], 5]"), i"[≥2, 5]") # the stalled limit spells as the infinity beyond it

    # Where no limit has a closed spelling, the argument comes back unchanged instead of throwing as in `normalize`.
    @test isequal(simplify(i"([1, typemax(Int)], typemax(Int)]"), i"([1, typemax(Int)], typemax(Int)]")
    @test isequal(simplify(i"(true, true)"), i"(true, true)")

    # An extreme of the element type names the same limit as the infinity beyond it, which is the canonical spelling.
    @test isequal(simplify(i"[5, typemax(Int)]"), i"≥5")
    @test isequal(simplify(i"[typemin(Int), 5]"), i"≤5")
    @test isequal(simplify(i"[typemin(Int), typemax(Int)]"), Line{Int}())
    @test isequal(simplify(i"[[typemin(Int), 5], 7]"), i"[≤5, 7]")
    @test isequal(simplify(i"[[typemin(Int), typemax(Int)], 5]"), ClosedClosed(Line{Int}(), 5)) # an endpoint that could take any value
    @test isequal(simplify(i"[big(5), big(9)]"), i"[big(5), big(9)]")
    @test isequal(simplify(i">5"), simplify(i"[6, typemax(Int)]")) # so `simplify` decides `==` again
end

@testset "Equality" begin
    # `==` asks about the members, so over a discrete element type different spellings agree.
    @test i"(3, 7)" == i"[4, 6]"
    @test i">4" == i"≥5"
    @test i"[5, 3]" == i"(5, 5)"              # every empty interval holds the same nothing
    @test i"[1, 2]" != i"(1, 2]"              # `{1, 2}` against `{2}`
    @test i"(3.0, 7.0)" != i"[4.0, 6.0]"      # a dense element type has no such collision
    @test i"[1, 2]" != i"[1, 3]"
    @test ismissing(i"[2, >4]" == i"[2, >4]") # an uncertain endpoint leaves the members open

    # An uncertainty that is down to a single value determines the endpoint all the same.
    @test i"[(1, 3), 7]" == i"[2, 7]"
    @test i"((1, 3), 7]" == i"[3, 7]"
    @test i"[(1, 3), 7]" != i"[3, 7]"
    @test ismissing(i"[(1, 5), 7]" == i"[2, 7]")
    @test ismissing(i"[(1, 5), 7]" == i"[(1, 5), 7]")

    # A dense element type reads its bounds the same way, as only the values decide.
    @test i"[[2.0, 2.0], 5.0]" == i"[2.0, 5.0]"
    @test i"([2.0, 2.0], 5.0)" == i"(2.0, 5.0)"
    @test i"[[2.0, 2.0], 5.0]" != i"(2.0, 5.0)"
    @test ismissing(i"[(1.0, 3.0), 5.0]" == i"[2.0, 5.0]")

    # `isequal` asks about the structure instead and always decides.
    @test !isequal(i"(3, 7)", i"[4, 6]")
    @test isequal(i"[4, 6]", i"[4, 6]")
    @test isequal(i"[2, >4]", i"[2, >4]")

    # A `BigInt` bound is not compared by its representation, so the `===` fallback is not enough.
    @test isequal(i"[big(1), big(2)]", i"[big(1), big(2)]")
    @test hash(i"[big(1), big(2)]") == hash(i"[big(1), big(2)]")
    @test length(Set([i"[big(1), big(2)]", i"[big(1), big(2)]"])) == 1
    @test get(Dict(i"[big(1), big(2)]" => :found), i"[big(1), big(2)]", :missed) === :found

    # `==` follows the order on the bounds, `isequal` distinguishes what they distinguish.
    @test i"[0.0, 1.0]" == i"[-0.0, 1.0]"
    @test !isequal(i"[0.0, 1.0]", i"[-0.0, 1.0]")

    # Another element type holds something else, so neither call it equal.
    @test i"[1, 2]" != i"[1.0, 2.0]"
    @test !isequal(i"[1, 2]", i"[1.0, 2.0]")

    # An extreme decides like any other value, and a bound at infinity meets the one written as a value.
    @test i"(typemax(Int), typemax(Int))" == i"[5, 3]"
    @test i"(-∞, 5]" == i"≤5"
    @test i"[0.0, Inf)" == i"≥0.0"
    @test i"[NaN, NaN]" == i"[1.0, 0.0]" # `NaN` compares with nothing, so the interval holds nothing
    @test isequal(i"[NaN, NaN]", i"[NaN, NaN]")
    @test hash(i"[4, +∞)") == hash(i"≥4")

    # A limit at infinity names the extreme of a discrete element type, as no member lies between the two.
    @test i">5" == i"[6, typemax(Int)]"
    @test i"[typemin(Int), typemax(Int)]" == Line{Int}()
    @test !isequal(i">5", i"[6, typemax(Int)]")
    @test Line{BigInt}() != i"[big(1), big(9)]" # without its guard the substitution would reach for `typemin(BigInt)`

    # `Inf` is a value sitting where the limit `+∞` is, so a bound closed at it holds a member that the ray leaves out, while an extreme below the limit leaves nothing between the two and merges the spellings. `⊆` pins the difference down: `i"≥0.0" ⊆ i"[0.0, Inf]"` holds and the converse does not.
    @test i"(-Inf, 5.0]" == i"≤5.0"
    @test i"[-Inf, 5.0]" != i"≤5.0"
    @test i"[0.0, Inf]" != i"≥0.0"
end

# The element types below separate two properties that `Int` and `Float64` happen to tie together: whether the type counts its values, and where its extreme sits relative to the limit beyond it.
UncertainIntervals.successor(x::Date) = x + Day(1)
UncertainIntervals.predecessor(x::Date) = x - Day(1)
# `Time` stays dense, so it is the type that is dense and still has no value at infinity.

# An `Int8` whose extremes stand in for the infinities, with `typemin(Int8)` as a `NaN`. This is the discrete counterpart of `Float64`: a type whose extreme sits *at* the limit rather than below it.
# An `Integer`, as its finite values are integers. `isfinite` and `isinteger` default to `true` there and have to be overridden, the same pair `Infinities` overrides for `ℵ₀`. Arithmetic is left out, as nothing here asks for it.
struct ExtInt8 <: Integer
    v::Int8
end
const NAN8 = ExtInt8(typemin(Int8))
const NEGINF8 = ExtInt8(typemin(Int8) + one(Int8))
const POSINF8 = ExtInt8(typemax(Int8))
Base.isnan(x::ExtInt8) = x.v == typemin(Int8)
Base.isinf(x::ExtInt8) = x == NEGINF8 || x == POSINF8
Base.isfinite(x::ExtInt8) = !isnan(x) && !isinf(x)
Base.isinteger(x::ExtInt8) = isfinite(x)
Base.signbit(x::ExtInt8) = x.v < zero(Int8)
Base.typemin(::Type{ExtInt8}) = NEGINF8
Base.typemax(::Type{ExtInt8}) = POSINF8
Base.isless(a::ExtInt8, b::ExtInt8) = !isnan(a) && !isnan(b) && a.v < b.v
Base.:(<)(a::ExtInt8, b::ExtInt8) = !isnan(a) && !isnan(b) && a.v < b.v
Base.:(<=)(a::ExtInt8, b::ExtInt8) = !isnan(a) && !isnan(b) && a.v <= b.v
Base.:(==)(a::ExtInt8, b::ExtInt8) = !isnan(a) && !isnan(b) && a.v == b.v
# The infinities and the `NaN` hash as the `Float64` ones do, which is what `==` against them claims.
Base.hash(x::ExtInt8, h::UInt) = hash(isnan(x) ? NaN : x == POSINF8 ? Inf : x == NEGINF8 ? -Inf : Float64(x.v), h)
Base.show(io::IO, x::ExtInt8) = print(io, isnan(x) ? "NaN8" : x == NEGINF8 ? "-Inf8" : x == POSINF8 ? "Inf8" : string(x.v))
UncertainIntervals.successor(x::ExtInt8) = isnan(x) || x == POSINF8 ? nothing : ExtInt8(x.v + one(Int8))
UncertainIntervals.predecessor(x::ExtInt8) = isnan(x) || x == NEGINF8 ? nothing : ExtInt8(x.v - one(Int8))

# A type carrying the order relations and nothing else. It is deliberately not a `Number`: Base's own `==(x::Number, y::Number)` promotes, so a `Number` owes a promotion rule, arithmetic and a hash, none of which this package asks for.
struct Approx
    v::Float64
end
Base.:(<)(a::Approx, b::Approx) = a.v < b.v
Base.:(<=)(a::Approx, b::Approx) = a.v <= b.v
Base.:(==)(a::Approx, b::Approx) = a.v == b.v

# The discrete counterpart of `Approx`: ordered, with neighbors, and nothing more.
struct Rung
    v::Int
end
Base.:(<)(a::Rung, b::Rung) = a.v < b.v
Base.:(<=)(a::Rung, b::Rung) = a.v <= b.v
Base.:(==)(a::Rung, b::Rung) = a.v == b.v
UncertainIntervals.successor(x::Rung) = Rung(x.v + 1)
UncertainIntervals.predecessor(x::Rung) = Rung(x.v - 1)

@testset "Discrete element type without a value at infinity" begin
    d1, d2 = Date(2024, 3, 1), Date(2024, 3, 8)
    @test isdiscrete(Date)
    @test -∞ < d1 < +∞
    @test isempty(OpenOpen(d1, d1 + Day(1))) # neighbours, so nothing lies between them
    @test !isempty(OpenOpen(d1, d1 + Day(2)))
    @test isequal(normalize(OpenOpen(d1, d2)), ClosedClosed(d1 + Day(1), d2 - Day(1)))
    @test OpenOpen(d1, d2) == ClosedClosed(d1 + Day(1), d2 - Day(1))
    @test d1 + Day(3) ∈ ClosedClosed(d1, d2)
    @test ClosedClosed(d1, d2) ⊆ ClosedOpen(d1, d2 + Day(1))

    # An extreme below the limit names the same limit as the infinity beyond it, and the substitution keeps the element type from ever meeting an infinity.
    @test !isempty(GreaterEqual(d1))
    @test isempty(Greater(typemax(Date)))
    @test !isempty(GreaterEqual(typemax(Date)))
    @test typemax(Date) ∈ GreaterEqual(d1)
    @test d1 ∈ Line{Date}()
    @test GreaterEqual(d1) == ClosedClosed(d1, typemax(Date))
    @test GreaterEqual(d1) ⊆ ClosedClosed(d1, typemax(Date))
    @test ClosedClosed(d1, typemax(Date)) ⊆ GreaterEqual(d1)
    @test isequal(simplify(ClosedClosed(d1, typemax(Date))), GreaterEqual(d1))
end

@testset "Dense element type without a value at infinity" begin
    t1, t2 = Time(1), Time(2)
    @test_throws MethodError t1 < +∞ # cyclic Time is deliberately not opted in
    @test !isdiscrete(Time)
    @test !isempty(OpenOpen(t1, t2))
    @test isempty(OpenOpen(t1, t1))
    @test !isempty(ClosedClosed(t1, t1))
    @test t1 + Nanosecond(1) ∈ OpenOpen(t1, t2)
    @test !(t1 ∈ OpenOpen(t1, t2))
    @test OpenOpen(t1, t2) != ClosedClosed(t1, t2) # no step joins the two spellings
    @test OpenOpen(t1, t2) ⊆ ClosedClosed(t1, t2)
    @test isequal(normalize(OpenOpen(t1, t2)), OpenOpen(t1, t2))
    @test !isempty(Line{Time}())

    # `typemin(Time)` and `typemax(Time)` stand in for the limits, so `Time` never meets an infinity.
    @test !isempty(GreaterEqual(t1))
    @test t2 ∈ GreaterEqual(t1)
    @test t1 ∈ Line{Time}()
    @test ClosedClosed(t1, t2) ⊆ Line{Time}()
    @test GreaterEqual(t1) ⊆ Line{Time}()

    # Nothing lies between `typemax(Time)` and the limit either, so these meet as they do over `Date`, although no step reaches from one to the other.
    @test GreaterEqual(t1) == ClosedClosed(t1, typemax(Time))
    @test isequal(simplify(ClosedClosed(t1, typemax(Time))), GreaterEqual(t1))
end

@testset "Discrete element type with a value at infinity" begin
    a, b = ExtInt8(0), ExtInt8(5)
    @test isdiscrete(ExtInt8)

    # Declaring the type a `Number` and answering `isinf` is all it takes: `Infinities` derives the rest.
    @test ExtInt8 <: Integer
    @test POSINF8 == +∞ && NEGINF8 == -∞
    @test +∞ == POSINF8 && -∞ == NEGINF8 # symmetric, as `Infinities` answers for both orders
    @test hash(POSINF8) == hash(∞) && hash(NEGINF8) == hash(-∞) # which is what `==` obliges
    @test POSINF8 != -∞ && NEGINF8 != +∞
    @test NAN8 != +∞ && NAN8 != -∞ && b != +∞

    # The predicates agree with one another, which the `Integer` defaults would not.
    @test isinf(POSINF8) && !isfinite(POSINF8) && !isinteger(POSINF8)
    @test isfinite(b) && isinteger(b) && !isinf(b) && !isnan(b)
    @test isnan(NAN8) && !isfinite(NAN8) && !isinf(NAN8)

    @test !isempty(ClosedClosed(a, b))
    @test isempty(OpenOpen(a, ExtInt8(1)))
    @test isequal(normalize(OpenOpen(a, b)), ClosedClosed(ExtInt8(1), ExtInt8(4)))
    @test ExtInt8(3) ∈ ClosedClosed(a, b)

    # A value the order relates to nothing is a member of nothing and holds nothing.
    @test !(NAN8 ∈ ClosedClosed(a, b))
    @test !(NAN8 ∈ Line{ExtInt8}())
    @test isempty(ClosedClosed(NAN8, NAN8))
    @test isempty(ClosedClosed(a, NAN8))

    # A bound at the extreme is a bound at the limit, so a bound open at the limit stops one value short of it.
    @test isempty(GreaterEqual(POSINF8))
    @test isempty(Greater(POSINF8))
    @test isempty(LessEqual(NEGINF8))
    @test isempty(Less(NEGINF8))
    @test !(NEGINF8 ∈ Line{ExtInt8}())
    @test ExtInt8(126) ∈ Line{ExtInt8}()
    @test GreaterEqual(a) ⊆ ClosedClosed(a, POSINF8)

    # `Inf8` is a value sitting where the limit is, exactly as `Inf` does over `Float64`, so a bound closed at it holds a member the ray leaves out.
    @test !(POSINF8 ∈ GreaterEqual(a))
    @test GreaterEqual(a) != ClosedClosed(a, POSINF8)
    @test ClosedClosed(a, POSINF8) ⊈ GreaterEqual(a)
    @test isequal(simplify(ClosedClosed(a, POSINF8)), ClosedClosed(a, POSINF8))
    @test isequal(simplify(ClosedClosed(a, ExtInt8(126))), GreaterEqual(a)) # the last value below the limit does name it
end

@testset "Rational carries its own infinities" begin
    # `Base.isinf` already names `±1//0`, so `Rational` is covered without it saying anything.
    @test 1//0 == +∞
    @test -1//0 == -∞
    @test 1//1 != +∞
    @test 1//0 != -∞
    @test -1//0 != +∞
    @test big(1)//0 == +∞ # a numerator that is not an `Int`
    @test !isdiscrete(Rational{Int})

    @test !(1//0 ∈ GreaterEqual(0//1)) # the ray is open where `1//0` sits
    @test 1//0 ∈ ClosedClosed(0//1, 1//0)
    @test GreaterEqual(0//1) != ClosedClosed(0//1, 1//0)
    @test GreaterEqual(0//1) ⊆ ClosedClosed(0//1, 1//0)
    @test ClosedClosed(0//1, 1//0) ⊈ GreaterEqual(0//1)
    @test isempty(GreaterEqual(1//0)) # nothing lies at the limit and below it at once
end

@testset "An element type ordered and nothing more" begin
    # Infinite bounds need direct infinity comparisons unless finite extrema can replace them.
    a, b = Approx(1.0), Approx(2.0)
    @test a != +∞ # the `===` fallback, as no method claims otherwise
    @test a != -∞
    @test !isdiscrete(Approx)
    @test !Base.hastypemax(Approx) # so no extreme stands in for a limit and the infinities stay put

    finite = ClosedClosed(a, b)
    @test !isempty(finite)
    @test b ∈ finite
    @test !(Approx(0.0) ∈ finite)
    @test finite == ClosedClosed(a, b)
    @test finite ⊆ ClosedClosed(Approx(0.0), b)
    @test isequal(normalize(finite), finite)
    @test isequal(simplify(finite), finite)
    @test_throws MethodError isempty(GreaterEqual(a))
    @test_throws MethodError b ∈ GreaterEqual(a)
    @test !isempty(Line{Approx}())
    @test_throws MethodError a ∈ Line{Approx}()
end

@testset "A discrete element type ordered and nothing more" begin
    a, b = Rung(1), Rung(5)
    @test isdiscrete(Rung)
    @test !Base.hastypemax(Rung)
    @test a != +∞

    @test !isempty(ClosedClosed(a, b))
    @test isempty(OpenOpen(a, Rung(2))) # neighbors, so nothing lies between them
    @test Rung(3) ∈ OpenOpen(a, b)
    @test !(a ∈ OpenOpen(a, b))
    @test OpenOpen(a, b) == ClosedClosed(Rung(2), Rung(4))
    @test OpenOpen(a, b) ⊆ ClosedClosed(Rung(2), Rung(4))
    @test isequal(normalize(OpenOpen(a, b)), ClosedClosed(Rung(2), Rung(4)))
    @test isequal(simplify(ClosedClosed(OpenOpen(Rung(0), Rung(2)), b)), ClosedClosed(Rung(1), b))
    @test_throws MethodError Rung(3) ∈ GreaterEqual(a)
end

@testset "Interval Literals" begin
    # A literal has to reproduce the structure, so these ask `isequal` rather than `==`.
    a, b = 3, 7
    @test isequal(i"[1, 2)", ClosedOpen(1, 2))
    @test isequal(i"(1.5, 2.5]", OpenClosed(1.5, 2.5))
    @test isequal(i"  [ 1 , 2 ]  ", ClosedClosed(1, 2))
    @test isequal(i">4", Greater(4))
    @test isequal(i"≥12", GreaterEqual(12))
    @test isequal(i"<5", Less(5))
    @test isequal(i"≤2.5", LessEqual(2.5))
    @test isequal(i">=12", GreaterEqual(12))
    @test isequal(i"<=2.5", LessEqual(2.5))
    @test isequal(i"[2, >=4]", ClosedClosed(2, GreaterEqual(4)))

    @test isequal(i"[a, b)", ClosedOpen(3, 7))
    @test isequal(i"[a + b, 2b]", ClosedClosed(10, 14))
    @test isequal(i"[max(1, 2), 5)", ClosedOpen(2, 5)) # the comma of a call must not split the interval

    # A bracket or comma inside a character or string literal is text, while a quote after a value is the adjoint operator.
    @test isequal(i"[')', '(']", ClosedClosed(')', '('))
    @test isequal(i"[',', 'z']", ClosedClosed(',', 'z'))
    @test isequal(i"[length(\"(,\"), 5]", ClosedClosed(2, 5))
    @test isequal(i"[length(\"\\\"\"), 5]", ClosedClosed(1, 5)) # an escaped quote does not end the literal
    @test isequal(i"[a', b)", ClosedOpen(3, 7))
    @test isequal(i"[length(\"ab\")', 5]", ClosedClosed(2, 5)) # a closing parenthesis ends a value too
    @test isequal(i"[big\"1.5\"', 3.0]", ClosedClosed(big"1.5", big"3.0")) # so does the quote closing a string literal

    @test isequal(i"[2, >4]", ClosedClosed(2, Greater(4)))
    @test isequal(i"(≥2.0, 5.2)", OpenOpen(GreaterEqual(2.0), 5.2))
    @test isequal(i"([-3.4, -2.87], ≥-1.4]", OpenClosed(ClosedClosed(-3.4, -2.87), GreaterEqual(-1.4)))
    @test isequal(i"[[1, 2], [3, 4]]", ClosedClosed(ClosedClosed(1, 2), ClosedClosed(3, 4)))

    @test isequal(i"[4, +∞)", GreaterEqual(4))
    @test isequal(i"[4, ∞)", GreaterEqual(4)) # a bare `∞` is the positive one
    @test isequal(i"(-∞, 5]", LessEqual(5))
    @test_throws ArgumentError i"(-∞, +∞)" # no bound carries the element type, so `Line{T}()` it is
    @test_throws ArgumentError i"[(-∞, +∞), 5]" # the same holds for a bound, which the literal builds first
    @test isequal(i"[Line{Int}(), 5]", ClosedClosed(Line{Int}(), 5))

    # An extreme of the element type is an ordinary bound, `Inf` included.
    @test isequal(i"(-∞, typemin(Int))", Less(typemin(Int)))
    @test isequal(i"[typemax(Int), +∞)", GreaterEqual(typemax(Int)))
    @test isequal(i"[-Inf, Inf]", ClosedClosed(-Inf, Inf))

    for x in (ClosedOpen(1, 4), Greater(4), LessEqual(2.5), ClosedClosed(2, OpenOpen(4, +∞)))
        @test isequal(eval(UncertainIntervals.interval_expr(sprint(print, x))), x)
    end

    # A bracketed string whose bounds do not split would reach Julia as a vector, which is called out rather than built.
    @test_throws ArgumentError UncertainIntervals.interval_expr("[1]")
    @test_throws ArgumentError UncertainIntervals.interval_expr("[1, 2, 3]")
end

@testset "Bottom" begin
    # `Union{}` is a subtype of every `Openness`, so no type parameter bound can keep it out.
    @test_throws ArgumentError Interval{Int, Union{}, RightOpen, Int, Int}(1, 2)
    @test_throws ArgumentError Interval{Int, LeftOpen, Union{}, Int, Int}(1, 2)
    @test_throws ArgumentError Interval{Int, Union{}, RightOpen}(1, 2)
    @test_throws ArgumentError Interval{Union{}, Union{}}(1, 2)
    @test_throws ArgumentError RightRay{Int, Union{}}(1)
    @test_throws Exception Interval{Union{}, LeftOpen, RightOpen, Int, Int}(1, 2)

    # `Union{}` reaching the constructor body says so itself rather than being taken for an `Interval`.
    @test_throws ArgumentError Line{Union{}}()
    @test_throws ArgumentError isdiscrete(Union{})

    # The same bound takes the `Openness` unions themselves.
    @test_throws ArgumentError Interval{Int, LeftOpenness, RightOpen, Int, Int}(1, 2)
    @test_throws ArgumentError Interval{Int, LeftOpen, RightOpenness, Int, Int}(1, 2)
    @test ClosedOpen(1, 2) isa Interval{Int, LeftClosed, RightOpen, Int, Int}

    @test !(Union{} isa typeunion(Openness))
    @test !(Openness isa typeunion(Openness))
    @test LeftOpen isa typeunion(Openness)
    @test !(Union{} isa typeunion(LeftOpenness; whole = true))
    @test LeftOpenness isa typeunion(LeftOpenness; whole = true)

    @test sprint(print, Union{}) == "Union{}"
    @test sprint(print, LeftOpen) == "("
    @test_throws Exception tryparse(Union{}, '(') # `Base.tryparse(::Type{Union{}}, slurp...)` catches this one
    @test_throws Exception chars(Union{})
    @test_throws Exception findfirst(Union{}, "[1,2)")
    @test findfirst(RightOpenness, "[1,2)") == 5
end

# Only the macros are imported, so an expansion naming anything of the package by symbol fails here.
module BareCaller
import UncertainIntervals: @i_str
const a, b = 3, 7
computed() = i"[a + b, 2b]" # the bounds resolve here, everything else must not
infinite() = i"[4, +∞)"
nested() = i"[2, >4]"
end

@testset "Macro Hygiene" begin
    # `@i_str` escapes its whole expression, so it has to splice type objects rather than their names.
    @test isequal(BareCaller.computed(), ClosedClosed(10, 14))
    @test isequal(BareCaller.infinite(), GreaterEqual(4))
    @test isequal(BareCaller.nested(), ClosedClosed(2, Greater(4)))
end
