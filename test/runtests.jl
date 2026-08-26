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

@testset "Parse Rays" begin
    @test tryparse(Interval{Int}, ">4") == Greater(4)
    @test tryparse(Interval{Int}, " < 5 ") == Less(5)
    @test tryparse(Interval{Int}, "≥12") == GreaterEqual(12)
    @test tryparse(Interval{Float64}, "≤2.5") == LessEqual(2.5)
end

@testset "Parse Uncertain Intervals" begin
    @test tryparse(Interval{Int}, "[2, >4]") == ClosedClosed(2, OpenOpen(4, +∞))
    @test tryparse(Interval{Float32}, "(≥2.0, 5.2)") == OpenOpen(ClosedOpen(2f0, +∞), 5.2f0)
    @test tryparse(Interval{Float32}, "(≥2, 5.2)") == OpenOpen(ClosedOpen(2f0, +∞), 5.2f0)
    @test tryparse(Interval{Float64}, "([-3.4, -2.87], ≥-1.4]") == OpenClosed(ClosedClosed(-3.4, -2.87), ClosedOpen(-1.4, +∞))

    @test_throws ArgumentError OpenOpen(-∞, +∞)
    @test tryparse(Interval{Int32}, "(-∞, ∞)") == OpenOpen{Int32}(-∞, +∞)
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
