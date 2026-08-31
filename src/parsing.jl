# ASCII delimiters can be found byte-wise, as every non-ASCII UTF-8 byte is `>= 0x80`. Wider code units are rejected rather than misread.
@inline utf8(s::AbstractString) = codeunits(s)::Base.CodeUnits{UInt8}

# A quote right after a value is the adjoint operator, which is how Julia reads it too: https://github.com/JuliaLang/julia/blob/ba658ebd8c246bc3f3489586a89073b337b501f9/JuliaSyntax/src/julia/tokenize.jl#L1108
@inline value_byte(b::UInt8) =
    b >= 0x80 || UInt8('0') <= b <= UInt8('9') || UInt8('A') <= b <= UInt8('Z') || UInt8('a') <= b <= UInt8('z') ||
    b in (UInt8('_'), UInt8('.'), UInt8(')'), UInt8(']'), UInt8('}'), UInt8('\''), UInt8('"'))

"""
    comma_index(s::AbstractString)

Return the index of the comma separating the two bounds of `s`, which is an interval already stripped of its enclosing brackets. Commas of nested bounds and of any call in between are skipped, so a remaining enclosing bracket would hide the wanted one a level deep. A bracket or comma inside a character or string literal is text and counts for nothing.
"""
function comma_index(s::AbstractString)::Union{Nothing, Int}
    depth = 0
    units = utf8(s)
    closing = UInt8('\0') # the quote a literal waits for, one of `'"'`, `'\''` and `'\0'` for none
    previous = UInt8('\0')
    i = firstindex(units)
    while i <= lastindex(units)
        b = units[i]
        if closing == UInt8('\0')
            if b == UInt8('"')
                closing = b
            elseif b == UInt8('\'')
                value_byte(previous) || (closing = b)
            elseif b in (UInt8('('), UInt8('['), UInt8('{'))
                depth += 1
            elseif b in (UInt8(')'), UInt8(']'), UInt8('}'))
                depth -= 1
            elseif b == UInt8(',') && depth == 0
                return i
            end
        elseif b == UInt8('\\')
            i += 1 # whatever follows the backslash is text
        elseif b == closing
            closing = UInt8('\0')
        end
        previous = b
        i += 1
    end
    return nothing
end

# Packing the pair lets a two-byte prefix be compared in one step, and the little-endian order matches a two-byte load on a little-endian host.
"""
    leading_pair(u::AbstractVector{UInt8})
    leading_pair(s::AbstractString)

Return the two leading bytes of `u` as one little-endian `UInt16`.
"""
Base.@propagate_inbounds function leading_pair(u::AbstractVector{UInt8})
    @boundscheck checkbounds(u, firstindex(u) : firstindex(u) + 1)
    @inbounds UInt16(u[begin]) | UInt16(u[begin + 1]) << 8
end
Base.@propagate_inbounds leading_pair(s::AbstractString) = s |> codeunits |> leading_pair

# Passing `f` in avoids materializing a tuple, which a `Union` with `nothing` would force onto the heap.
"""
    split_interval(f, str::AbstractString)

Return `f` applied to the left `Openness`, the right `Openness` and the two bounds of `str`, which is an interval in `print` format such as `"[1, 2)"`. The bounds are handed over as substrings, so their meaning is left to `f`. A `str` of a different form gives `nothing` and leaves `f` uncalled.
"""
function split_interval(f, str::AbstractString)
    s = strip(str)
    @⊤ ncodeunits(s) >= ncodeunits("(a,b)")
    left_openness = @∃ tryparse(LeftOpenness, s |> first)
    right_openness = @∃ tryparse(RightOpenness, s |> last)
    inner = @view s[2 : prevind(s, lastindex(s))] # Left indexing is ok due to the interval bound, but we can have anything before the end
    n = @∃ comma_index(inner)
    left, right = strip(@view inner[1 : prevind(inner, n)]), strip(@view inner[n+1 : end]) # a comma is ASCII, so `n+1` works
    @⊥ isempty(left) || isempty(right)
    return f(left_openness, right_openness, left, right)
end

# Each branch hands over one fixed comparison, which keeps `f` specialized where a loop over the comparisons would leave the type to be applied at run time.
"""
    split_comparison(f, str::AbstractString)

Return `f` applied to the comparison type `str` begins with and to the rest of `str`. A `str` beginning with no comparison gives `nothing` and leaves `f` uncalled.
"""
function split_comparison(f, str::AbstractString)
    s = strip(str)
    units = utf8(s)
    @⊥ isempty(s)
    leading = ncodeunits(s) >= 2 ? (@inbounds leading_pair(units)) : UInt16(units[1]) # a lone byte leaves the high half zero, which matches none of the spellings
    leading == leading_pair(">=") && return f(GreaterEqual, @view s[1 + ncodeunits(">=") : end])
    leading == leading_pair("<=") && return f(LessEqual, @view s[1 + ncodeunits("<=") : end])
    units[1] == UInt8('>') && return f(Greater, @view s[1 + ncodeunits(">") : end])
    units[1] == UInt8('<') && return f(Less, @view s[1 + ncodeunits("<") : end])
    # `≥` and `≤` share their leading pair, so the byte after it is all that tells them apart.
    @⊤ ncodeunits(s) >= ncodeunits("≥") && leading == leading_pair("≥")
    units[ncodeunits("≥")] == last(codeunits("≥")) && return f(GreaterEqual, @view s[1 + ncodeunits("≥") : end])
    units[ncodeunits("≤")] == last(codeunits("≤")) && return f(LessEqual, @view s[1 + ncodeunits("≤") : end])
    return nothing
end

# Handed in for upstreaming: https://github.com/JuliaMath/Infinities.jl/pull/76
"""
    _tryparse(::Type{RealInfinity}, s::AbstractString)

Return the infinity `s` denotes, or `nothing` if it denotes none. A bare `∞` is the positive one, as only that is a valid bound on its own.
"""
function _tryparse(::Type{RealInfinity}, s::AbstractString)
    all(isspace, s) && return nothing
    negative = tryparse(NegativeInfinity, s)
    isnothing(negative) || return negative
    return tryparse(PositiveInfinity, s)
end


# The parametric `Type{C}` position makes this specialize on the comparison, which a plain closure argument would not.
"""
    tryparse_bound(::Type{C}, ::Type{T}, bound::AbstractString)

Return the comparison `C` over `bound` parsed as `T`, or `nothing` if `bound` is no `T`. `bound` is what follows the comparison operator, so `Greater` and `"12"` give `>12`.
"""
@inline tryparse_bound(::Type{C}, ::Type{T}, bound::AbstractString) where {C,T} = C(@∃ tryparse(T, bound))

for Cmp in Comparisons
    @eval @inline Base.tryparse(::Type{<:$Cmp{T}}, str::AbstractString) where T = split_comparison(str) do Spelled, rest
        Spelled === $Cmp ? tryparse_bound($Cmp, T, rest) : nothing
    end
end

function Base.tryparse(::Type{<:Comparison{T}}, str::AbstractString) where T
    split_comparison(str) do Cmp, rest
        tryparse_bound(Cmp, T, rest)
    end
end

@inline function parse_certain_interval(::Type{T}, left_openness::LeftOpenness, right_openness::RightOpenness, left_str::AbstractString, right_str::AbstractString)::Union{Nothing, CertainInterval{T}} where T
    left = @∃ tryparse(T, left_str)
    right = @∃ tryparse(T, right_str)

    # return Interval{left_openness, right_openness}(left, right)::CertainInterval{T} # Julia should be able to efficiently handle this
    isclosed(left_openness) && isclosed(right_openness) && return ClosedRegular{T}(left, right)
    isopen(left_openness) && isopen(right_openness) && return OpenRegular{T}(left, right)
    isclosed(left_openness) && isopen(right_openness) && return ClosedOpenRegular{T}(left, right)
    return OpenClosedRegular{T}(left, right) # or at least efficiently handle this – but it can't with Julia 1.13, although this is the least inefficient
end

function Base.tryparse(::Type{<:CertainInterval{T}}, str::AbstractString) where T
    split_interval(str) do left_openness, right_openness, left_str, right_str
        parse_certain_interval(T, left_openness, right_openness, left_str, right_str)
    end
end

# A target which pins the openness leaves a single type, so it is built directly and an input of another openness is rejected. `typeunion` matches those four types invariantly, where a `<:` bound would also cover their union and lose to the method above.
@inline function Base.tryparse(R::typeunion(CertainInterval{T}), str::AbstractString) where T
    split_interval(str) do left_openness, right_openness, left_str, right_str
        @⊤ R <: Interval{T, typeof(left_openness), typeof(right_openness)}
        left = @∃ tryparse(T, left_str)
        right = @∃ tryparse(T, right_str)
        R(left, right)
    end
end

# Not a `tryparse` method, as `Line{T}` and the comparisons meet where `T` is itself an infinity.
"""
    tryparse_line(::Type{T}, str::AbstractString)

Return the line over `T` if `str` spells it, and `nothing` otherwise. Only a bound reaches this, as an interval of its own takes the element type from nowhere and `Line{T}()` names it instead.
"""
function tryparse_line(::Type{T}, str::AbstractString) where T
    split_interval(str) do left_openness, right_openness, left_str, right_str
        @⊤ isopen(left_openness) && isopen(right_openness)
        @∃ tryparse(NegativeInfinity, left_str)
        @∃ tryparse(PositiveInfinity, right_str)
        Line{T}()
    end
end

function Base.tryparse(::Type{Inner{T}}, s::AbstractString) where T
    @∃⏎ tryparse(T, s)
    @∃⏎ tryparse(Comparison{T}, s)
    @∃⏎ tryparse_line(T, s)
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

    split_interval(s) do left_openness, right_openness, left_str, right_str
        left = @∃ tryparse(LeftInner{T}, left_str)
        right = @∃ tryparse(RightInner{T}, right_str)
        Interval{T, left_openness |> typeof, right_openness |> typeof}(left, right)
    end
end

"""
    interval_expr(str::AbstractString)

Return the expression an interval in `print` format stands for. A bound which is no interval itself is handed to Julia verbatim, so it can be any expression, except for a vector, which no bound can be.
"""
function interval_expr(str::AbstractString)
    s = strip(str)
    @∃⏎ _tryparse(RealInfinity, s) # the value goes into the expression, so no name has to resolve in the caller's module
    expr = split_comparison(s) do Cmp, rest
        :($Cmp($(interval_expr(rest))))
    end
    isnothing(expr) || return expr
    expr = split_interval(s) do left_openness, right_openness, left, right
        :($Interval{$(left_openness |> typeof), $(right_openness |> typeof)}($(interval_expr(left)), $(interval_expr(right))))
    end
    isnothing(expr) || return expr
    bound = Meta.parse(s)
    # A bracketed `str` whose bounds do not split reaches Julia as a vector, which would build silently.
    bound isa Expr && bound.head === :vect && "`$s` is no interval, and a vector is no bound" |> ArgumentError |> throw
    return bound
end

"""
    i"[1, 2)"

Construct an `Interval` written the way it is printed. Each bound is a Julia expression, so `i"[a, f(b))"` works.
"""
macro i_str(str::String)
    str |> interval_expr |> esc
end
