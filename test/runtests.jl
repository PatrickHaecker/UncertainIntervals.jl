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
    # @test tryparse(Interval{Int}, ">4") == Greater(4)
end

# Test infinity handling
# TODO: Fix
# @testset "Infinity Handling" begin
#     # Test negative infinity
#     neg_inf = Interval(Open, Open, NegativeInfinity, 5.0)
#     @test neg_inf.left == NegativeInfinity

#     # Test positive infinity
#     pos_inf = Interval(Open, Open, 5.0, PositiveInfinity)
#     @test pos_inf.right == PositiveInfinity
# end

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

# Test helper functions
# @testset "Helper Functions" begin
#     # Test left_tryparse
#     @test left_tryparse(Openness, '(') == Open()
#     @test left_tryparse(Openness, '[') == Closed()
#     @test left_tryparse(Openness, 'a') === nothing

#     # Test right_tryparse
#     @test right_tryparse(Openness, ')') == Open()
#     @test right_tryparse(Openness, ']') == Closed()
#     @test right_tryparse(Openness, 'a') === nothing
# end

# Test interval printing
# @testset "Interval Printing" begin
#     # Test that intervals can be printed
#     interval = Interval(Closed, Closed, 1, 2)
#     io = IOBuffer()
#     print(io, interval)
#     output = String(take!(io))
#     @test output != ""
# end

