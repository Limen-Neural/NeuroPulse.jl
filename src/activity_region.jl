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
                min_leak::Float32=0.01f0,
                max_leak::Float32=0.25f0,
                stress_adapter=nothing) -> nothing

Adapt the base leak rate based on a generic stress signal.

Higher stress maps to a higher leak rate. Higher leak makes neurons harder to fire,
naturally inducing sparsity and reducing power consumption. This enables
hardware-software co-design where the SNN dynamically responds to thermal or
other stress conditions.

# Stress contract

- `stress` is any real-valued stress signal.
- When `stress_adapter` is `nothing` (default), `stress` is treated as a
  fan-speed-like percentage in `[0, 100]` and mapped to the unit interval via
  `clamp(stress / 100, 0, 1)` (preserves previous behavior).
- When `stress_adapter` is provided, it is called as `stress_adapter(stress)`
  and must return a value in `[0, 1]` (callers are responsible for clamping if
  needed). That unit value is then linearly interpolated between `min_leak` and
  `max_leak`.

# Arguments

  - `leak_rate` — reference to the current leak rate (modified in-place)
  - `stress` — stress signal (default interpretation: fan speed percentage)
  - `min_leak` — leak at zero stress (default `0.01f0`)
  - `max_leak` — leak at full stress (default `0.25f0`)
  - `stress_adapter` — optional callable `stress -> [0,1]`; `nothing` uses the
    default fan-speed adapter
"""
function adapt_leak!(leak_rate::Ref{Float32}, stress::Real;
                     min_leak::Float32 = 0.01f0,
                     max_leak::Float32 = 0.25f0,
                     stress_adapter = nothing)
    if stress_adapter === nothing
        normalized = clamp(Float32(stress) / 100.0f0, 0.0f0, 1.0f0)
    else
        normalized = Float32(stress_adapter(stress))
    end
    leak_rate[] = min_leak + normalized * (max_leak - min_leak)
    return nothing
end
