"""
    comma_index(s::AbstractString)

Return the index of the comma separating the two bounds of `s`, which is an interval already stripped of its enclosing brackets. Commas of nested bounds and of any call in between are skipped, so a remaining enclosing bracket would hide the wanted one a level deep.
"""
function comma_index(s::AbstractString)::Union{Nothing, Int}
    depth = 0
    units = codeunits(s) # ASCII delimiters can be found byte-wise, as every non-ASCII UTF-8 byte is `>= 0x80`
    for i in eachindex(units)
        b = units[i]
        if b == UInt8('(') || b == UInt8('[') || b == UInt8('{')
            depth += 1
        elseif b == UInt8(')') || b == UInt8(']') || b == UInt8('}')
            depth -= 1
        elseif b == UInt8(',') && depth == 0
            return i
        end
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
    units = codeunits(s)
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
    isclosed(left_openness) && isclosed(right_openness) && return ClosedClosedInner{T}(left, right)
    isopen(left_openness) && isopen(right_openness) && return OpenOpenInner{T}(left, right)
    isclosed(left_openness) && isopen(right_openness) && return ClosedOpenInner{T}(left, right)
    return OpenClosedInner{T}(left, right) # or at least efficiently handle this – but it can't with Julia 1.13, although this is the least inefficient
end

function Base.tryparse(::Type{<:CertainInterval{T}}, str::AbstractString) where T
    split_interval(str) do left_openness, right_openness, left_str, right_str
        parse_certain_interval(T, left_openness, right_openness, left_str, right_str)
    end
end

# A target which pins the openness admits a single type, so it is built directly and an input of another openness is rejected. `typeunion` matches those four types invariantly, where a `<:` bound would also cover their union and lose to the method above.
@inline function Base.tryparse(R::typeunion(CertainInterval{T}), str::AbstractString) where T
    split_interval(str) do left_openness, right_openness, left_str, right_str
        @⊤ R <: Interval{T, typeof(left_openness), typeof(right_openness)}
        left = @∃ tryparse(T, left_str)
        right = @∃ tryparse(T, right_str)
        R(left, right)
    end
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

    split_interval(s) do left_openness, right_openness, left_str, right_str
        left = @∃ tryparse(LeftInner{T}, left_str)
        right = @∃ tryparse(RightInner{T}, right_str)
        Interval{T, left_openness |> typeof, right_openness |> typeof}(left, right)
    end
end

"""
    interval_expr(str::AbstractString)

Return the expression an interval in `print` format stands for. A bound which is no interval itself is handed to Julia verbatim, so it can be any expression.
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
    return isnothing(expr) ? Meta.parse(s) : expr
end

"""
    i"[1, 2)"

Construct an `Interval` written the way it is printed. Each bound is a Julia expression, so `i"[a, f(b))"` works.
"""
macro i_str(str::String)
    str |> interval_expr |> esc
end
