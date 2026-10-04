# Every pair of intervals needs a method, as `isequal` would otherwise fall back on `==` and inherit set identity.
Base.isequal(x::AInterval{T1,O1ₗ,O1ᵣ}, y::AInterval{T2,O2ₗ,O2ᵣ}) where {T1,O1ₗ,O1ᵣ,T2,O2ₗ,O2ᵣ} =
    T1 === T2 && O1ₗ === O2ₗ && O1ᵣ === O2ᵣ && isequal(x.left, y.left) && isequal(x.right, y.right)
# Machine numbers compare so cheaply that comparing both bounds beats branching after the first.
Base.isequal(x::AInterval{T,Oₗ,Oᵣ}, y::AInterval{T,Oₗ,Oᵣ}) where {T <: Union{Base.IEEEFloat, Base.BitInteger}, Oₗ, Oᵣ} =
    isequal(x.left, y.left) & isequal(x.right, y.right)

# The type parameters fold into a single constant, leaving only the limits to hash at runtime.
Base.hash(x::AInterval{T,Oₗ,Oᵣ}, h::UInt) where {T,Oₗ,Oᵣ} = hash(x.right, hash(x.left, h + hash((T, Oₗ, Oᵣ))))

# The bits of all limits, nested ones included, are packed into as few words as possible, their structure folds into the seed.
Base.hash(x::AInterval{T}, h::UInt) where T <: Union{Base.IEEEFloat, Base.BitInteger} =
    foldl((h, w) -> hash(w, h), words(bitpatterns(T, x)); init = h + hash((T, shape(T, x |> typeof))))

"""
    tryconvert(T, v::Union{NegativeInfinity, PositiveInfinity})

Return `convert(T, v)`, or `nothing` where that throws an `InexactError`, as for an integer type.

Infinities.jl converts `v` to the extreme of `T` where that `isinf`, as `Inf` for a float, so this decides without catching anything.
"""
@inline tryconvert(::Type{T}, v::PositiveInfinity) where T = Base.hastypemax(T) && isequal(typemax(T), v) ? typemax(T) : nothing
@inline tryconvert(::Type{T}, v::NegativeInfinity) where T = Base.hastypemax(T) && isequal(typemin(T), v) ? typemin(T) : nothing

"""
    bitpatterns(T, x)::NTuple{N, U}

Return every limit of `x` from left to right, nested ones included, with its bit pattern read as the unsigned integer type `U` of the width of `T`. Two such tuples are equal exactly where the limits are `isequal`:

- Every `NaN` gets the same bits.
- An infinity `v` gets the bits of [`tryconvert(T, v)`](@ref tryconvert), or none where that is `nothing`, as [`shape`](@ref) already records it.

So `[(1, -3), ∞)` over `Int8` gives `(0x01, 0xfd)`, and `(1.5, ∞)` over `Float64` gives `(0x3ff8000000000000, 0x7ff0000000000000)`.

This makes `hash` cheap. `Base` hashes a number so that `hash(1) == hash(1.0)`, which costs work per value. Intervals are only `isequal` over the same `T`, so comparing the bits suffice, and `words` packs narrow ones into fewer words to hash.
"""
@inline bitpatterns(::Type, v::Base.BitInteger) = (unsigned(v), )
@inline bitpatterns(::Type, v::Base.IEEEFloat) = (reinterpret(Unsigned, ifelse(isnan(v), oftype(v, NaN), v)), )
@inline function bitpatterns(::Type{T}, v::Union{NegativeInfinity, PositiveInfinity}) where T
    w = tryconvert(T, v)
    return isnothing(w) ? () : bitpatterns(T, w)
end
@inline bitpatterns(::Type{T}, x::AInterval) where T = (bitpatterns(T, x.left)..., bitpatterns(T, x.right)...)

"""
    shape(T, X::Type)

Return what the type `X` of an interval over `T` fixes about its limits: the openness at every level and, where an infinity does not [`tryconvert`](@ref) to `T`, which limits are infinite.

It seeds `hash`, so the hashed bits of [`bitpatterns`](@ref) only need to carry the values.

So `[(1, -3), ∞)` over `Int8` gives `(LeftClosed, (LeftOpen, nothing, nothing, RightOpen), PositiveInfinity, RightOpen)`, in the order the interval is written, with the `∞` that `bitpatterns` leaves out. `(1.5, ∞)` over `Float64` gives `(LeftOpen, nothing, nothing, RightOpen)`, as its `∞` is hashed as `Inf`.
"""
shape(::Type, ::Type) = nothing
shape(::Type{T}, ::Type{L}) where {T, L <: Union{NegativeInfinity, PositiveInfinity}} = isnothing(tryconvert(T, L())) ? L : nothing
shape(::Type{T}, ::Type{<:AInterval{<:Any,Oₗ,Oᵣ,L,R}}) where {T,Oₗ,Oᵣ,L,R} = (Oₗ, shape(T, L), shape(T, R), Oᵣ)


# Narrower than a word, so two of them fit into one integer of twice the width.
const NarrowUnsigned = Union{UInt8, UInt16, UInt32}

"""
    words(xs::Tuple)

Return the unsigned integers `xs` packed into as few 64-bit words as [`pairup`](@ref) can, so `hash` mixes in one word where it would mix in several integers.

So the bit patterns `(0x01, 0xfd, 0x00)` of `Int8` limits become `(0x0000000001fd0000,)`, while 64-bit integers stay as they are.

Each round of pairing halves the count, so `n` integers of `b` bits end up in `cld(n * b, 64)` words, the fewest possible. Once inlined, it compiles to the same shifts and ors as packing each case by hand, as checked for the 2 to 4 limits an interval has.
"""
@inline words(xs::Tuple{U, Vararg{U}}) where U <: NarrowUnsigned = words(pairup(xs))
@inline words(xs::Tuple) = xs

"""
    pairup(xs::Tuple{U, Vararg{U}}) where U <: Union{UInt8, UInt16, UInt32}

Return the unsigned integers `xs` with each adjacent pair joined into one of twice the width, the first in the high half, and a last unpaired one widened alone.

So `(0x01, 0xfd, 0x00)` becomes `(0x01fd, 0x0000)`. See [`words`](@ref).
"""
@inline pairup((a, b, r...)::Tuple{U, U, Vararg{U}}) where U <: NarrowUnsigned = (widen(a) << 8sizeof(a) | b, pairup(r)...)
@inline pairup((a, )::Tuple{NarrowUnsigned}) = (widen(a), )
@inline pairup(::Tuple{}) = ()
