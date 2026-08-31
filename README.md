# UncertainIntervals.jl

Intervals whose endpoints may be uncertain.

```julia
i"[1, 2)"            # a certain interval with closed left-bound and open right-bound
i"≥12"               # a ray
i"[2, >4]"           # the right endpoint is some value above 4
i"[(1.0, 2.0], 7.0]" # the left endpoint `l` is uncertain, but constrained by `1.0 < l ≤ 2.0`
```

## A bound is a value, an interval, a ray or a line

An endpoint you know is a value. An endpoint you only know within limits is the interval, ray or line of the values it could take. The outer brackets still say whether the endpoints belong to the interval.

```julia
ClosedClosed(1, 2)                # [1, 2]
Greater(4)                        # >4
Line{Int}()                       # (-∞, +∞)
ClosedClosed(ClosedOpen(1, 5), 7) # [[1, 5), 7], a left endpoint somewhere in [1, 5)
tryparse(Interval{Int}, "[1, 2)") # the literal without the macro
```

Any ordered type will do:

```julia
ClosedOpen(v"1.2", v"2")                 # [1.2.0, 2.0.0), a compat bound
i"[Date(2024, 3, 1), Date(2024, 3, 8)]"  # [2024-03-01, 2024-03-08], a week
# [[2024-03-01, 2024-03-03], 2024-03-08], an outage that began within the first three days
i"[[Date(2024, 3, 1), Date(2024, 3, 3)], Date(2024, 3, 8)]"
```

Every shape above is its own type. A collection of different interval structures can become a large `Union` type. Spelling each bound as a closed interval, degenerate wherever the endpoint is known, gives one concrete type for known and unknown endpoints alike:

```julia
a = i"[[1, 1], [2, 2]]" # the endpoints are 1 and 2
b = i"[[1, 5], [7, 7]]" # the left endpoint is somewhere in [1, 5]
typeof(a) === typeof(b) # true, so `[a, b]` stays concretely typed
a == i"[1, 2]"          # true, as the spelling does not change the members (see below)
```

## An answer can be undecided

```julia
isempty(i"[3, 1]")            # true
isempty(i"[(3, 5), 1]")       # true, every possible left endpoint exceeds the right one
isempty(i"[(1, 3), 2]")       # false, over `Int` the uncertainty pins the left endpoint to 2
isempty(i"[(1.0, 3.0), 2.0]") # missing, the left endpoint may fall on either side of 2.0
```

Such answers are `Union{Bool, Missing}`. Certain endpoints always decide, so those keep returning a `Bool` and stay usable as a condition.

## An element type is discrete or dense

A **discrete** type counts its values, a **dense** one stands for values it merely approximates. A type is discrete once it has a `successor`, so `Integer` is and `Float64` is not: `(3, 7)` and `[4, 6]` hold the same three `Int`s, while `(3.0, 7.0)` and `[nextfloat(3.0), prevfloat(7.0)]` differ although no `Float64` lies between their endpoints. Two methods move a type to the discrete side:

```julia
UncertainIntervals.successor(x::Float64) = nextfloat(x)
UncertainIntervals.predecessor(x::Float64) = prevfloat(x)
```

A `Date` counts days, yet starts out dense all the same, as it is no `Integer`:

```julia
UncertainIntervals.successor(x::Date) = x + Day(1)
UncertainIntervals.predecessor(x::Date) = x - Day(1)
normalize(i"(Date(2024, 3, 1), Date(2024, 3, 8))") # [2024-03-02, 2024-03-07] (see below)
```
A `Char` counts too and starts out dense as well, but there the step has to be chosen rather than derived, as `'\ud800'` to `'\udfff'` are no characters and `typemax(Char)` is none either, so counting code points and counting characters require different implementations of `successor(::Char)` and `predecessor(::Char)`.

The `successor` docstring states the rest of the contract, such as the round trip both steps have to make.

## `==` asks about members, `isequal` about structure

```julia
i"(3, 7)" == i"[4, 6]"         # true, as over `Int` both hold exactly 4, 5 and 6
isequal(i"(3, 7)", i"[4, 6]")  # false, as openness and endpoints differ
i">5" == i"[6, typemax(Int)]"  # true, as no `Int` lies above `typemax(Int)`
```

`==` returns `Union{Bool, Missing}` and compares members by the order, so `i"[5, 3]" == i"(5, 5)"` holds (every empty interval holds the same nothing) and so does `i"[0.0, 1.0]" == i"[-0.0, 1.0]"`. `isequal` and `hash` always decide and keep both pairs apart, which is what, e.g., `Dict` and `Set` need.

## `∞` is a limit, `Inf` and `typemax` are values

`-∞` and `+∞` mark a bound no value reaches, so such a bound is always open and holds no member. `Inf` is an ordinary `Float64` and `typemax(Int)` an ordinary `Int`, so either can be a member. Over a discrete element type the two spellings then meet, as no member lies between an extreme and the infinity beyond it:

```julia
ClosedOpen(-∞, 5)              # ArgumentError, a bound at a limit cannot be closed
isempty(i"(typemax(Int), +∞)") # true, no `Int` lies between the extreme and the limit
!isempty(i"[Inf, Inf]")        # true, `Inf` is a value an interval can hold
i"(-Inf, 5.0]" == i"≤5.0"      # true, both leave `-Inf` out
```

## `normalize` and `simplify`

`normalize` returns the closed form, moving every finite limit a step inwards until it is closed, which only a discrete type has to do. Each bound keeps its shape, so the result type follows from the argument type. `simplify` goes on to drop an uncertainty that is down to a single value, which no type can know in advance, so it is not type-safe.

```julia
normalize(i"(3, 7)")      # [4, 6]
normalize(i"((1, 3), 7]") # [[3, 3], 7]
simplify(i"((1, 3), 7]")  # [3, 7]
```
