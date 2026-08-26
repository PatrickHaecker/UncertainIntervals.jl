function _tryparse(::Type{NegativeInfinity}, s::AbstractString) # TODO: Switch to upstreamed version when available
    i = findfirst(!isspace, s)
    s[i] == '-' || return nothing
    i = findnext(!isspace, s, nextind(s, i)) # A space can have multiple codeunits
    s[i] == '∞' || return nothing
    return findnext(!isspace, s, i + ncodeunits('∞')) |> isnothing ? NegativeInfinity() : nothing
end
# @test _tryparse(NegativeInfinity, "-∞") == NegativeInfinity()
# @test _tryparse(NegativeInfinity, " - ∞ ") == NegativeInfinity()
# @test _tryparse(NegativeInfinity, "∞ ") |> isnothing
# @test _tryparse(NegativeInfinity, "3-∞") |> isnothing
# @test _tryparse(NegativeInfinity, "-+∞") |> isnothing
# @test _tryparse(NegativeInfinity, "-∞2") |> isnothing

function _tryparse(::Type{PositiveInfinity}, s::AbstractString) # TODO: Switch to upstreamed version when available
    i = findfirst(!isspace, s)
    if s[i] == '+'
        i = findnext(!isspace, s, nextind(s, i)) # A space can have multiple codeunits
    end
    s[i] == '∞' || return nothing
    return findnext(!isspace, s, i + ncodeunits('∞')) |> isnothing ? PositiveInfinity() : nothing
end
# @test _tryparse(PositiveInfinity, "+∞") == PositiveInfinity()
# @test _tryparse(PositiveInfinity, " + ∞ ") == PositiveInfinity()
# @test _tryparse(PositiveInfinity, "∞") == PositiveInfinity()
# @test _tryparse(PositiveInfinity, " ∞ ") == PositiveInfinity()
# @test _tryparse(PositiveInfinity, "-∞") |> isnothing
# @test _tryparse(PositiveInfinity, "+-∞") |> isnothing
# @test _tryparse(PositiveInfinity, "--∞") |> isnothing
# @test _tryparse(PositiveInfinity, "-∞∞") |> isnothing


function Base.tryparse(::Type{<:CertainInterval{T}}, str::AbstractString) where T
    # We want to do `match(r"([([])\s*([^,]+)\s*,\s*([^,]+)\s*([)\]])", s)`, but allocation-free

    s = strip(str)

    @⊤ ncodeunits(s) >= ncodeunits("(1,2)")
    @∃ left_openness = tryparse(LeftOpenness, s |> first)
    @∃ right_openness = tryparse(RightOpenness, s |> last)

    return tryparse_inner(CertainInterval{T}, @view(s[2 : prevind(s, end)]), left_openness, right_openness) # Left indexing is correct due to ASCII, but we can have anything before the end
end

@inline function tryparse_inner(::Type{<:CertainInterval{T}}, s::AbstractString, left_openness::LeftOpenness, right_openness::RightOpenness) where T
    @∃ n = findnext(',', s, 1)
    @∄ findnext(',', s, n+1) # +1 is correct, as the comma is ASCII

    @∃ left = tryparse(T, @view s[1 : prevind(s, n)])
    @∃ right = tryparse(T, @view s[n+1 : end])

    # return Interval(left_openness, right_openness, left, right)::CertainInterval{T} # Julia should be able to efficiently handle this
    # return Interval{T, T, T, left_openness |> typeof, right_openness |> typeof}(left, right) # or at least handle this
    isclosed(left_openness) && isclosed(right_openness) && return ClosedClosedInner{T}(left, right)
    isopen(left_openness) && isopen(right_openness) && return OpenOpenInner{T}(left, right)
    isclosed(left_openness) && isopen(right_openness) && return ClosedOpenInner{T}(left, right)
    return OpenClosedInner{T}(left, right) # or at least efficiently handle this – but it can't with Julia 1.13, although this is the least inefficient
end

Base.tryparse(::Type{<:Greater{T}},      s::AbstractString) where T = s[1] == '>' ? tryparse(T, @view s[1+ncodeunits('>') : end]) |> Greater      : nothing
Base.tryparse(::Type{<:GreaterEqual{T}}, s::AbstractString) where T = s[1] == '≥' ? tryparse(T, @view s[1+ncodeunits('≥') : end]) |> GreaterEqual : nothing
Base.tryparse(::Type{<:Less{T}},         s::AbstractString) where T = s[1] == '<' ? tryparse(T, @view s[1+ncodeunits('<') : end]) |> Less         : nothing
Base.tryparse(::Type{<:LessEqual{T}},    s::AbstractString) where T = s[1] == '≤' ? tryparse(T, @view s[1+ncodeunits('≤') : end]) |> LessEqual    : nothing

function Base.tryparse(::Type{<:Comparison{T}}, str::AbstractString) where T
    s = strip(str)
    @∃⏎ tryparse(Greater{T}, s)
    @∃⏎ tryparse(GreaterEqual{T}, s)
    @∃⏎ tryparse(Less{T}, s)
    tryparse(LessEqual{T}, s)
end

function Base.tryparse(::Type{Inner{T}}, s::AbstractString) where T
    @∃⏎ tryparse(T, s)
    @∃⏎ tryparse(Comparison{T}, s)
    tryparse(CertainInterval{T}, s)
end

function Base.tryparse(::Type{LeftInner{T}}, s::AbstractString) where T
    @∃⏎ tryparse(Inner{T}, s)
    _tryparse(NegativeInfinity, s)
end

function Base.tryparse(::Type{RightInner{T}}, s::AbstractString) where T
    @∃⏎ tryparse(Inner{T}, s)
    _tryparse(PositiveInfinity, s)
end

function Base.tryparse(::Type{<:Interval{T}}, str::AbstractString) where T
    s = strip(str)

    @∃⏎ tryparse(Comparison{T}, s)

    @⊤ ncodeunits(s) >= ncodeunits("(1,2)")
    @∃ left_openness = tryparse(LeftOpenness, s |> first)
    @∃ right_openness = tryparse(RightOpenness, s |> last)
    s = strip(@view s[2 : prevind(s, end)]) # Left indexing is ok due to interval bound, but we can have anything before the end

    is_left_interval = s[1] in ('(', '[')
    start_pos = nextind(s, is_left_interval ? findfirst(RightOpenness, s) : 1) # Use `nextind` because it can be '≤' or '≥'
    comma_pos = findnext(',', s, start_pos)
    @∃ left = tryparse(LeftInner{T}, @view s[1 : prevind(s, comma_pos)]) # we can have anything before the comma, so `prevind` it is
    @∃ right = tryparse(RightInner{T}, @view s[comma_pos+1 : end]) # a comma is ASCII, so +1 works

    # TODO: Change to `Interval`
    return LeftRight{T, left_openness |> typeof, right_openness |> typeof}(left, right)
    # return LeftRight{T, left_openness, right_openness}(left, right)
end

macro i_str(str::String)

    str |> typeof |> println
end