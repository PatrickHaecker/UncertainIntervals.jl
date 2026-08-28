using Test
using UseAll

@useall UncertainIntervals

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
    @test Interval{Int, LeftOpen, RightClosed}(-4.0, 2) == OpenClosed(-4, 2)
    @test Line{Int}() == OpenOpen{Int}(-∞, +∞)
    @test sprint(print, Line{Float64}()) == "(-∞, +∞)"
end

@testset "Conversion" begin
    @test convert(ClosedOpen{Int}, ClosedClosed(1.0, 2.0)) == ClosedOpen(1, 2)
end

# Test interval parsing
@testset "Parse Certain Intervals" begin
    @test tryparse(CertainInterval{Int}, "(1, 2)") == OpenOpen(1, 2)
    @test tryparse(CertainInterval{Int}, "(1, 2]") == OpenClosed(1, 2)
    @test tryparse(CertainInterval{Int}, "[1, 2)") == ClosedOpen(1, 2)
    @test tryparse(CertainInterval{Int}, "[1, 2]") == ClosedClosed(1, 2)
end

@testset "Parse Certain Intervals with spaces" begin
    @test tryparse(CertainInterval{Int}, "[1,2]") == ClosedClosed(1, 2)
    @test tryparse(CertainInterval{Int}, "[  1  ,  2  ]") == ClosedClosed(1, 2)
    @test tryparse(CertainInterval{Int}, "  [  1  ,  2  ]  ") == ClosedClosed(1, 2)
end
@testset "Parse Certain Intervals with a fixed openness" begin
    # `===` also pins the type down to the one asked for.
    @test tryparse(OpenOpenInner{Int}, "(1, 2)") === OpenOpen(1, 2)
    @test tryparse(OpenClosedInner{Int}, "(1, 2]") === OpenClosed(1, 2)
    @test tryparse(ClosedOpenInner{Int}, "[1, 2)") === ClosedOpen(1, 2)
    @test tryparse(ClosedClosedInner{Int}, "[1, 2]") === ClosedClosed(1, 2)

    # Any other openness is a parse failure rather than a differently typed interval.
    @test isnothing(tryparse(OpenOpenInner{Int}, "[1, 2)"))
    @test isnothing(tryparse(OpenOpenInner{Int}, "(1, 2]"))
    @test isnothing(tryparse(OpenOpenInner{Int}, "[1, 2]"))
    @test isnothing(tryparse(ClosedClosedInner{Int}, "(1, 2)"))
    @test isnothing(tryparse(ClosedOpenInner{Int}, "(1, 2]"))
    @test isnothing(tryparse(OpenClosedInner{Int}, "[1, 2)"))

    @test isnothing(tryparse(ClosedOpenInner{Int}, "no interval"))
    @test isnothing(tryparse(ClosedOpenInner{Int}, "[x, 2)"))
end
@testset "Parse Rays" begin
    @test tryparse(Interval{Int}, ">4") == Greater(4)
    @test tryparse(Interval{Int}, " < 5 ") == Less(5)
    @test tryparse(Interval{Int}, "≥12") == GreaterEqual(12)
    @test tryparse(Interval{Float64}, "≤2.5") == LessEqual(2.5)

    @test tryparse(Interval{Int}, ">=12") == GreaterEqual(12)
    @test tryparse(Interval{Float64}, "<=2.5") == LessEqual(2.5)
    @test tryparse(Interval{Int}, "  >= 4 ") == GreaterEqual(4)

    # A bound which does not parse must fail the whole ray, not become its element.
    @test isnothing(tryparse(Interval{Int}, "<x"))
    @test isnothing(tryparse(Interval{Int}, ">=x"))
    @test isnothing(tryparse(Interval{Int}, ">"))
end

@testset "Parse Uncertain Intervals" begin
    @test tryparse(Interval{Int}, "[2, >4]") == ClosedClosed(2, OpenOpen(4, +∞))
    @test tryparse(Interval{Float32}, "(≥2.0, 5.2)") == OpenOpen(ClosedOpen(2f0, +∞), 5.2f0)
    @test tryparse(Interval{Float32}, "(≥2, 5.2)") == OpenOpen(ClosedOpen(2f0, +∞), 5.2f0)
    @test tryparse(Interval{Float64}, "([-3.4, -2.87], ≥-1.4]") == OpenClosed(ClosedClosed(-3.4, -2.87), ClosedOpen(-1.4, +∞))

    @test_throws ArgumentError OpenOpen(-∞, +∞)
    @test tryparse(Interval{Int32}, "(-∞, ∞)") == OpenOpen{Int32}(-∞, +∞)
end

@testset "Printing" begin
    @test sprint(print, ClosedOpen(2.0, 5.0)) == "[2.0, 5.0)"
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

    # The same bound admits the `Openness` unions themselves.
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
