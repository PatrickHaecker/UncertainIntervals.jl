# TODO: Should maybe be ControlFlowMacros.jl

#               default                        ⏎ (\varcarriagereturn)
# ∃     @∃: exists and continue              @∃⏎: exists and return
# ∄     @∄: does not exist and continue      @∄⏎: does not exist and return
# ⊤     @⊤: true and continue                @⊤⏎: true and return
# ⊥     @⊥: false and continue               @⊥⏎: false and return

"""
    @∃ regular exceptional=nothing

Ensure a `regular` value exists (being not `nothing`) and evalute to its value. Otherwise exit the enclosing function returning `exceptional`.

`exceptional` is `nothing` by default, but it can be a subtype of Exception, too, or any other value.

In some situations this is a cheap alternative to `throw`: The rest of the current function execution can rely on the value not being nothing while the caller of the current function optionally gets an indication about what went wrong.

"""
macro ∃(regular, exceptional=nothing) # non-nothing continues; nothing returns exceptional
    :(temp = $(regular |> esc); isnothing(temp) ? (return $(exceptional |> esc)) : temp)
end

"nothing continues; non-nothing returns exceptional"
macro ∄(regular, exceptional=nothing)
    :($(regular |> esc) |> isnothing ? nothing : (return $(exceptional |> esc)))
end

"non-nothing returns its value; nothing continues as exceptional"
macro ∃⏎(regular, exceptional=nothing)
    :(temp = $(regular |> esc); isnothing(temp) ? $(exceptional |> esc) : return temp)
end

"nothing returns its value; non-nothing continues as exceptional"
macro ∄⏎(regular, exceptional=nothing)
    :($(regular |> esc) |> isnothing ? (return nothing) : $(exceptional |> esc))
end


"[See also](https://en.wikipedia.org/wiki/Truth_value)"
macro ⊤(condition, exceptional=nothing)
    :($(condition |> esc) ? true : (return $(exceptional |> esc)))
end

macro ⊥(condition, exceptional=nothing)
    :($(condition |> esc) ? (return $(exceptional |> esc)) : false)
end

macro ⊤⏎(condition, exceptional=nothing)
    :($(condition |> esc) ? (return true) : $(exceptional |> esc))
end

macro ⊥⏎(condition, exceptional=nothing)
    :($(condition |> esc) ? $(exceptional |> esc) : (return false))
end