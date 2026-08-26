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

    # return Interval{left_openness, right_openness}(left, right)::CertainInterval{T} # Julia should be able to efficiently handle this
    isclosed(left_openness) && isclosed(right_openness) && return ClosedClosedInner{T}(left, right)
    isopen(left_openness) && isopen(right_openness) && return OpenOpenInner{T}(left, right)
    isclosed(left_openness) && isopen(right_openness) && return ClosedOpenInner{T}(left, right)
    return OpenClosedInner{T}(left, right) # or at least efficiently handle this – but it can't with Julia 1.13, although this is the least inefficient
end

# TODO: Generate
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
    tryparse(NegativeInfinity, s)
end

function Base.tryparse(::Type{RightInner{T}}, s::AbstractString) where T
    @∃⏎ tryparse(Inner{T}, s)
    tryparse(PositiveInfinity, s)
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

    return Interval{T, left_openness, right_openness}(left, right)
end

macro i_str(str::String)

    str |> typeof |> println
end