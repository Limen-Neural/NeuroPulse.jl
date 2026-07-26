# SPDX-License-Identifier: MIT OR Apache-2.0
# activity_region.jl — Generic activity region state for relevance routing

"""
    ActivityRegion

Minimal per-region summary consumed by the routing kernel each tick.

Fields:
  last_spike_rate  — normalised firing rate [0,1] for this region this tick
  output           — N_OUT-element readout vector (CPU Float32)
"""
struct ActivityRegion
    last_spike_rate::Float32
    output::Vector{Float32}
end

"""
    ActivityRegion(n_out::Int) -> ActivityRegion

Construct a zero-initialised ActivityRegion with `n_out` output channels.
"""
ActivityRegion(n_out::Int) = ActivityRegion(0.0f0, zeros(Float32, n_out))

"""
    adapt_leak!(leak_rate::Ref{Float32}, stress::Real;
                min_leak::Real=0.01f0,
                max_leak::Real=0.25f0,
                stress_adapter=nothing) -> nothing

Adapt the base leak rate based on a generic stress signal.

Higher stress maps to a higher leak rate. Higher leak makes neurons harder to fire,
naturally inducing sparsity and reducing power consumption. This enables
hardware-software co-design where the SNN dynamically responds to thermal or
other stress conditions.

# Stress contract

- `stress` is any real-valued stress signal.
- When `stress_adapter` is `nothing` (default), `stress` is treated as a
  percent-scale signal in `[0, 100]` and mapped to the unit interval via
  `clamp(Float32(stress / 100), 0, 1)`. This preserves the previous default
  call shape (values that used to be fan-speed percents still work).
- When `stress_adapter` is provided, it is called as `stress_adapter(stress)`
  and the return value is clamped to `[0, 1]` before interpolation.
- The normalized unit value must be finite; `NaN` inputs or adapter outputs
  raise `ArgumentError` rather than silently producing a `NaN` leak rate.

# Arguments

  - `leak_rate` — reference to the current leak rate (modified in-place)
  - `stress` — stress signal (default interpretation: percent-scale in `[0, 100]`)
  - `min_leak` — leak at zero stress (default `0.01f0`); any `Real`, converted to `Float32`
  - `max_leak` — leak at full stress (default `0.25f0`); any `Real`, converted to `Float32`
  - `stress_adapter` — optional callable `stress -> [0,1]`; `nothing` uses the
    default percent-scale `[0, 100]` → unit adapter

# Errors

Throws `ArgumentError` if `min_leak` or `max_leak` is not finite, if
`min_leak > max_leak` after conversion to `Float32`, or if the normalized
unit stress value is not finite.
"""
function adapt_leak!(
    leak_rate::Ref{Float32},
    stress::Real;
    min_leak::Real = 0.01f0,
    max_leak::Real = 0.25f0,
    stress_adapter = nothing,
)
    lo = Float32(min_leak)
    hi = Float32(max_leak)
    if !isfinite(lo) || !isfinite(hi)
        throw(ArgumentError("min_leak and max_leak must be finite, got ($lo, $hi)"))
    end
    if lo > hi
        throw(ArgumentError("min_leak ($lo) must be <= max_leak ($hi)"))
    end
    if stress_adapter === nothing
        # divide in wider precision first, then narrow (avoids Float32 stress truncation)
        normalized = clamp(Float32(stress / 100), 0.0f0, 1.0f0)
    else
        normalized = clamp(Float32(stress_adapter(stress)), 0.0f0, 1.0f0)
    end
    if !isfinite(normalized)
        throw(ArgumentError("normalized stress must be finite, got $normalized"))
    end
    leak_rate[] = lo + normalized * (hi - lo)
    return nothing
end
