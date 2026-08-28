# TODO: Should maybe be ControlFlowMacros.jl

#               default                        ⏎ (\varcarriagereturn)
# ∃     @∃: exists and continue              @∃⏎: exists and return
# ∄     @∄: does not exist and continue      @∄⏎: does not exist and return
# ⊤     @⊤: true and continue                @⊤⏎: true and return
# ⊥     @⊥: false and continue               @⊥⏎: false and return

"""
    @∃ regular exceptional=nothing

Ensure a `regular` value exists (being not `nothing`) and evaluate to its value. Otherwise exit the enclosing function returning `exceptional`.

`exceptional` is `nothing` by default, but it can be a subtype of Exception, too, or any other value.

In some situations this is a cheap alternative to `throw`: The rest of the current function execution can rely on the value not being nothing while the caller of the current function optionally gets an indication about what went wrong.

"""
macro ∃(regular, exceptional=nothing) # non-nothing continues; nothing returns exceptional
    :(temp = $(regular |> esc); isnothing(temp) ? (return $(exceptional |> esc)) : temp)
end

"""
    @∄ regular exceptional=nothing

Ensure a `regular` value does not exist (being `nothing`) and evaluate to `nothing`. Otherwise exit the enclosing function returning `exceptional`.
"""
macro ∄(regular, exceptional=nothing)
    :($(regular |> esc) |> isnothing ? nothing : (return $(exceptional |> esc)))
end

"""
    @∃⏎ regular exceptional=nothing

Exit the enclosing function returning the `regular` value if it exists (being not `nothing`). Otherwise evaluate to `exceptional` and continue.
"""
macro ∃⏎(regular, exceptional=nothing)
    :(temp = $(regular |> esc); isnothing(temp) ? $(exceptional |> esc) : return temp)
end

"""
    @∄⏎ regular exceptional=nothing

Exit the enclosing function returning `nothing` if the `regular` value does not exist. Otherwise evaluate to `exceptional` and continue.
"""
macro ∄⏎(regular, exceptional=nothing)
    :($(regular |> esc) |> isnothing ? (return nothing) : $(exceptional |> esc))
end


"""
    @⊤ condition exceptional=nothing

Ensure `condition` holds and evaluate to `true`. Otherwise exit the enclosing function returning `exceptional`.

[See also](https://en.wikipedia.org/wiki/Truth_value)
"""
macro ⊤(condition, exceptional=nothing)
    :($(condition |> esc) ? true : (return $(exceptional |> esc)))
end

"""
    @⊥ condition exceptional=nothing

Ensure `condition` fails and evaluate to `false`. Otherwise exit the enclosing function returning `exceptional`.
"""
macro ⊥(condition, exceptional=nothing)
    :($(condition |> esc) ? (return $(exceptional |> esc)) : false)
end

"""
    @⊤⏎ condition exceptional=nothing

Exit the enclosing function returning `true` if `condition` holds. Otherwise evaluate to `exceptional` and continue.
"""
macro ⊤⏎(condition, exceptional=nothing)
    :($(condition |> esc) ? (return true) : $(exceptional |> esc))
end

"""
    @⊥⏎ condition exceptional=nothing

Exit the enclosing function returning `false` if `condition` fails. Otherwise evaluate to `exceptional` and continue.
"""
macro ⊥⏎(condition, exceptional=nothing)
    :($(condition |> esc) ? $(exceptional |> esc) : (return false))
end