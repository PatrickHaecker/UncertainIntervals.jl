using Test
using UseAll
using Infinities
using Aqua, JET

@useall UncertainIntervals

# Comparing against an empty vector rather than asking `isempty` so that a failure names the offending pair.
@testset "Method Ambiguities" begin
    @test detect_ambiguities(UncertainIntervals) == []
end

@testset "Aqua" begin
    # `Inner{T}` is a type of this package, and the gated `hash` fills a gap in `Infinities` for as long as the gap is there.
    Aqua.test_all(UncertainIntervals; unbound_args = false,
        piracies = (; treat_as_own = [Inner, NegativeInfinity, PositiveInfinity]))

    # Julia does solve `T` out of `Type{Inner{T}}`, which the check cannot see. Anything else unbound still fails.
    bounds = (which(tryparse, Tuple{Type{Inner{Int}}, AbstractString}),
              which(tryparse, Tuple{Type{LeftInner{Int}}, AbstractString}),
              which(tryparse, Tuple{Type{RightInner{Int}}, AbstractString}))
    @test issubset(Aqua.detect_unbound_args_recursively(UncertainIntervals), bounds)
end

@testset "JET" begin
    # These two index with the `nothing` from `findfirst`, which `_tryparse` guards against. Everything else stays in scope, `Base` included.
    upstream = (which(tryparse, Tuple{Type{NegativeInfinity}, AbstractString}),
                which(tryparse, Tuple{Type{PositiveInfinity}, AbstractString}))
    JET.test_package(UncertainIntervals; ignored_modules = JET.LastFrameMethod.(upstream))
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

    # The extremes take the same limits as `normalize`, so they collapse and throw alike.
    @test isequal(simplify(i"(typemin(Int), typemax(Int))"), i"[typemin(Int) + 1, typemax(Int) - 1]")
    @test isequal(simplify(i"[[typemax(Int), typemax(Int)], 5]"), i"[typemax(Int), 5]")
    @test isequal(simplify(i"[[Inf, Inf], 5.0]"), i"[Inf, 5.0]")
    @test isequal(simplify(i"[-Inf, Inf]"), i"[-Inf, Inf]")
    @test isequal(simplify(i"([1, typemax(Int)], 5]"), i"[≥2, 5]") # the stalled limit spells as the infinity beyond it
    @test isequal(simplify(i">5"), simplify(i"[6, typemax(Int)]")) # so `simplify` decides `==` again
end


@testset "Interval Literals" begin
    a, b = 3, 7
    @test i"[1, 2)" == ClosedOpen(1, 2)
    @test i"(1.5, 2.5]" == OpenClosed(1.5, 2.5)
    @test i"  [ 1 , 2 ]  " == ClosedClosed(1, 2)
    @test i">4" == Greater(4)
    @test i"≥12" == GreaterEqual(12)
    @test i"<5" == Less(5)
    @test i"≤2.5" == LessEqual(2.5)
    @test i">=12" == GreaterEqual(12)
    @test i"<=2.5" == LessEqual(2.5)
    @test i"[2, >=4]" == ClosedClosed(2, GreaterEqual(4))

    @test i"[a, b)" == ClosedOpen(3, 7)
    @test i"[a + b, 2b]" == ClosedClosed(10, 14)
    @test i"[max(1, 2), 5)" == ClosedOpen(2, 5) # the comma of a call must not split the interval

    @test i"[2, >4]" == ClosedClosed(2, Greater(4))
    @test i"(≥2.0, 5.2)" == OpenOpen(GreaterEqual(2.0), 5.2)
    @test i"([-3.4, -2.87], ≥-1.4]" == OpenClosed(ClosedClosed(-3.4, -2.87), GreaterEqual(-1.4))
    @test i"[[1, 2], [3, 4]]" == ClosedClosed(ClosedClosed(1, 2), ClosedClosed(3, 4))

    @test i"[4, +∞)" == GreaterEqual(4)
    @test i"[4, ∞)" == GreaterEqual(4) # a bare `∞` is the positive one
    @test i"(-∞, 5]" == LessEqual(5)
    @test_throws ArgumentError i"(-∞, +∞)" # no bound carries the element type, so `Line{T}()` it is

    for x in (ClosedOpen(1, 4), Greater(4), LessEqual(2.5), ClosedClosed(2, OpenOpen(4, +∞)))
        @test eval(UncertainIntervals.interval_expr(sprint(print, x))) == x
    end
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

# Test macro functionality
@testset "Macro Functionality" begin
    @test !isnothing(@∃ 42)
    @test !isnothing(@⊤ true)
    @test !isnothing(@⊥ false)
end

# Test string interpolation
# @testset "String Interpolation" begin
#     # Test i_str macro
#     str = @i_str "test"
#     @test str == "test"
# end
