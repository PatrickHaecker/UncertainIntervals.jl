using Test
using UseAll

@useall UncertainIntervals

@testset "UncertainIntervals.jl" begin

    # Test basic interval construction
    @testset "Basic Interval Construction" begin
        # Test certain interval
        interval = ClosedClosed(1.0, 2.0)
        @test interval.left == 1.0
        @test interval.right == 2.0
        @test interval isa Interval{Float64}
    end

    # Test interval parsing
    @testset "Interval Parsing" begin
        # Test parsing closed interval
        parsed = tryparse(CertainInterval{Int}, "(1, 2]")
        @test parsed isa Interval{Int}
        @test parsed.left == 1
        @test parsed.right == 2

        # Test parsing with different openness
        @test tryparse(CertainInterval{Int}, "[1, 2)") == Interval{Int, Int, Int, Closed, Open}(1, 2)
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

    # # Test string interpolation
    # @testset "String Interpolation" begin
    #     # Test i_str macro
    #     str = @i_str "test"
    #     @test str == "test"
    # end

    # # Test helper functions
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

    # # Test interval printing
    # @testset "Interval Printing" begin
    #     # Test that intervals can be printed
    #     interval = Interval(Closed, Closed, 1, 2)
    #     io = IOBuffer()
    #     print(io, interval)
    #     output = String(take!(io))
    #     @test output != ""
    # end

end
