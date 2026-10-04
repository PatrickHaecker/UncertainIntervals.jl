# UncertainIntervals.jl

Intervals whose endpoints may be uncertain.

```julia
i"[1, 2)"            # a certain interval with closed left-bound and open right-bound
i"≥12"               # a ray
i"[2, >4]"           # the right endpoint is some value above 4
i"[(1.0, 2.0], 7.0]" # the left endpoint `l` is uncertain, but constrained by `1.0 < l ≤ 2.0`
```

## Functionality

### Bounds as values or intervals

An endpoint you know is a value. An endpoint you only know within limits is the interval of the values it could take, a ray and a line included. The outer brackets still say whether the endpoints belong to the interval.

```julia
ClosedClosed(1, 2)                # [1, 2]
Greater(4)                        # >4, a ray
Line{Int}()                       # (-∞, +∞)
ClosedClosed(ClosedOpen(1, 5), 7) # [[1, 5), 7], a left endpoint somewhere in [1, 5)
i"[[1, 5), 7]"                    # the same one, written the way it prints
```

The `i"…"` macro spares you the constructors: write the interval as you would read it. It expands to the constructor call while your code compiles, so nothing is parsed at run time. Each bound can be any expression, as in `i"[a + b, 2b]"`.

Element types are not limited to numbers. `VersionNumber` and `Date` already bring the order an interval reads its members with, so they can be used as-is. [Element Types](#element-types) covers a type of your own.

```julia
ClosedOpen(v"1.2", v"2")                 # [1.2.0, 2.0.0), a compat bound
i"[Date(2024, 3, 1), Date(2024, 3, 8)]"  # [2024-03-01, 2024-03-08], a week
i"[[Date(2024, 3, 1), Date(2024, 3, 3)], Date(2024, 3, 8)]" # e.g., an outage that began within the first three days
```

Every shape above is its own type. A collection of different interval structures can become a large `Union` type. Spelling each bound as a closed interval, degenerated wherever the endpoint is known, gives one concrete type for known and unknown endpoints alike:

```julia
a = i"[[1, 1], [2, 2]]" # the endpoints are 1 and 2
b = i"[[1, 5], [7, 7]]" # the left endpoint is somewhere in [1, 5]
typeof(a) === typeof(b) # true, so `[a, b]` stays concretely typed
a == i"[1, 2]"          # true, as the spelling does not change the members (see below)
```

### Undecided Answers

```julia
isempty(i"[3, 1]")            # true
isempty(i"[(3, 5), 1]")       # true, every possible left endpoint exceeds the right one
isempty(i"[(1, 3), 2]")       # false, over `Int` the uncertainty pins the left endpoint to 2
isempty(i"[(1.0, 3.0), 2.0]") # missing, the left endpoint may fall on either side of 2.0

9 in i"[(1, 9), 20]"          # true, every possible left endpoint stays below 9
5 in i"[(1, 9), 20]"          # missing, a left endpoint of 8 would leave 5 out

i"[1, 2]" ⊆ i"[(1, 3), 7]"    # false, over `Int` the left endpoint can only be 2
i"[1, 2]" ⊆ i"[[1, 3], 7]"    # missing, a left endpoint of 2 keeps 1 out, one of 1 does not
```

Such answers are `Union{Bool, Missing}`. Certain endpoints always decide, so those keep returning a `Bool` and stay usable as a condition.

### `==` and `isequal`

`==` asks about members, `isequal` about structure:

```julia
i"(3, 7)" == i"[4, 6]"         # true, as over `Int` both hold exactly 4, 5 and 6
isequal(i"(3, 7)", i"[4, 6]")  # false, as openness and endpoints differ
i">5" == i"[6, typemax(Int)]"  # true, as no `Int` lies above `typemax(Int)`
```

`==` returns `Union{Bool, Missing}` and compares members by the order, so `i"[5, 3]" == i"(5, 5)"` holds (every empty interval holds the same nothing) and so does `i"[0.0, 1.0]" == i"[-0.0, 1.0]"`. `isequal` and `hash` always decide and keep both pairs apart, which is what, e.g., `Dict` and `Set` need.

### `normalize` and `simplify`

`normalize` gives every limit its closed spelling wherever it is identical, so `(3, 7)` becomes `[4, 6]`. Which limits have one is up to the element type, which is what [Element Types](#element-types) is about, so an interval over a dense type comes back unchanged. Each bound keeps its shape, so the result type follows from the argument type. `simplify` goes on to drop an uncertainty that is down to a single value, which is a property of the values rather than of the type, so the operation is not type-safe. Depending on your data, it can, however, be a good base for future type-safe operations.

```julia
normalize(i"(3, 7)")      # [4, 6]
normalize(i"(3.0, 7.0)")  # (3.0, 7.0]
normalize(i"((1, 3), 7]") # [[3, 3], 7]
simplify(i"((1, 3), 7]")  # [3, 7]
```

## Element Types

### Total preorder

Implementing

```julia
Base.isless(a::T, b::T)   # `<` calls it, and `<=` is `(a < b) | (a == b)`
```

is mandatory. Additionally,

```julia
Base.:(==)(a::T, b::T)
```

becomes mandatory if `==` differs from `===`.

Together they make `<=`, and a total preorder is all the package asks of it. Antisymmetry is not part of that: two values relating both ways are read as one member rather than assumed `==`, which is why `i"[0.0, 1.0]" == i"[-0.0, 1.0]"`.

Values with `v <= v` results in `false` are excluded from the interval. This is, e.g., the case for `NaN`. Without `==` the `===` fallback decides, two `NaN`s of your type are `===`, so `v <= v` stays `true` and the package reads such a value as an ordinary one:

```julia
struct Fuzzy; v::Float64; end
Base.isless(a::Fuzzy, b::Fuzzy) = isless(a.v, b.v)
Fuzzy(NaN) in Line{Fuzzy}()                   # true, though no interval holds such a value
isempty(ClosedClosed(Fuzzy(NaN), Fuzzy(NaN))) # false, though the interval holds nothing

Base.:(==)(a::Fuzzy, b::Fuzzy) = a.v == b.v   # both answers turn around
```

### Discrete or dense

A **discrete** type counts its values, a **dense** one stands for values it merely approximates. A type is discrete once it has a `successor`, so `Integer` is and `Float64` is not by default: `(3, 7)` and `[4, 6]` hold the same three `Int`s, while `(3.0, 7.0)` and `[nextfloat(3.0), prevfloat(7.0)]` differ although no `Float64` lies between their endpoints. This is using the interpretation of "approximations of the real numbers". You can also interpret `Float64`s as a collection of discrete values with non-uniform spacing, that's your decision.

Two methods define that a type is discrete:

```julia
UncertainIntervals.successor(x::Float64) = nextfloat(x)
UncertainIntervals.predecessor(x::Float64) = prevfloat(x)
```

which is done for all `Integer`s and only them by default. You can overrule this, e.g., with
```julia
`isdiscrete(::Type{Int16}) = false`
```

A `Date` counts days, yet starts out dense, as it is no `Integer`:

```julia
UncertainIntervals.successor(x::Date) = x + Day(1)
UncertainIntervals.predecessor(x::Date) = x - Day(1)
```

This enables, e.g., normalization:

```julia
normalize(i"(Date(2024, 3, 1), Date(2024, 3, 8))") # [2024-03-02, 2024-03-07]
```

A `Char` counts too and is initially dense, as you need to define the step, as `'\ud800'` to `'\udfff'` are no valid codepoints and `typemax(Char)` is none either, so counting code points and counting characters require different implementations of `successor(::Char)` and `predecessor(::Char)`. Therefore, the definition depends on what you want to achieve.

The `successor` docstring states the rest of the contract, such as the round trip both steps have to make.

### Dedicated infinity values

This is the second axis. `-∞` and `+∞` mark a bound no value reaches, so such a bound is always open and holds no member. They and their types `NegativeInfinity` and `PositiveInfinity` come from [Infinities.jl](https://github.com/JuliaMath/Infinities.jl) and are re-exported here.

Most types have no infinity of their own: nothing lies between their largest value and `+∞`. Stopping just below `+∞` then takes in the same values as stopping at that largest value:

```julia
ClosedOpen(-∞, 5)              # ArgumentError, a bound at a limit cannot be closed
i">5" == i"[6, typemax(Int)]"  # true, no `Int` lies beyond `typemax(Int)`
isempty(i"(typemax(Int), +∞)") # true, and nothing is left between the two
i"≥Time(1)" == i"[Time(1), typemax(Time)]" # true, and `Time` is dense
```

Where a type has an infinity of its own, such as `Inf`, that is a value of the type rather than the limit: `Inf == +∞` places it where the limit is, yet like any value it can be a closed endpoint and a member. A bound at the limit `+∞` itself stays open and leaves `Inf` out. `Number`s get their order against the limits from Infinities. A custom non-`Real` type modeling an unbounded Archimedean scale can opt in with `Infinities.@archimedean T`; the Dates extension does this for `Date`, `DateTime` and the mutually ordered period groups, but not cyclic `Time`.

If `T` has `typemin` and `typemax`, an infinite bound is read as a closed bound at that extreme. Where the extreme is the type's own infinity, a discrete type steps one value inward instead, and a dense one keeps `±∞`. Any other `T` must compare with `±∞` itself. UncertainIntervals does not invent such an order: for a type that is merely ordered, `x in i"≥a"` throws a `MethodError`, as `x < +∞` has no method, and so does every operation that compares an element with an infinite bound.

```julia
Inf == +∞                 # true, `Inf` is a value sitting where the limit is
Inf in i"≥0.0"            # false, the ray is open there
i"≥0.0" ⊆ i"[0.0, Inf]"   # true, and the converse is false, as only the bound holds `Inf`
i"(-Inf, 5.0]" == i"≤5.0" # true, both leave `-Inf` out
!isempty(i"[Inf, Inf]")   # true, `Inf` is an ordinary value an interval can hold
```

Each of the four combinations works:

|              | no infinity of its own  | an infinity of its own |
| --- | --- | --- |
| **discrete** | `Int`, `Date` (as above)| an `Int8` using `typemin`/`typemax` as infinities |
| **dense**    | `Time`                  | `Float64`, `Rational` |

Only together do they decide the behavior. A discrete type steps from its own infinity down to the neighbor, so its ray ends one value below it. A dense one has no step to take and keeps the `+∞`, which is why `i"[0.0, Inf)" == i"≥0.0"` holds over `Float64`.

That `Int8` is an `Integer`, so it needs nothing of this package either: answering `isinf` is enough for `==` against the limit to come out right. Being a number with infinities, it overrides whatever its supertype presumes about them, `isfinite` and `isinteger` under `Integer`, as `Infinities` does for `ℵ₀`.

### Method summary

Beyond the [total preorder](#total-preorder), every method is optional:

| method | what it adds |
| --- | --- |
| `convert(::Type{T}, x)` | bounds that are not `T`s yet, as in `ClosedClosed{Int}(1, 2.0)`; a bound that already is a `T` needs nothing |
| `successor(x)`, `predecessor(x)` | `T` counts its values, so `(3, 7)` and `[4, 6]` hold the same members |
| `isdiscrete(::Type{T})` | overrules that, where the neighbors serve another purpose |
| `typemin(T)`, `typemax(T)` | together, an infinite bound becomes the extreme, so `>5` equals `[6, typemax(T)]` |
| `Infinities.@archimedean T` | orders a non-`Real` `T` against `±∞` |
| `isless`, `==`, `hash` against `±∞` | a non-`Number` with an infinity of its own, in both argument orders |
| `tryparse(T, ::AbstractString)` | `parse(Interval{T}, "...")` reads a string at run time; `i"[a, b]"` needs nothing, as it parses Julia |
| `isequal(a, b)`, `hash(a, h)` | intervals over `T` serve as `Dict` keys and `Set` elements |
