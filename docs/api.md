# NeuroPulse API notes

This document summarizes the exported API as it exists today.

## Exported types and functions

```julia
LobeState
NeroOrchestrator
update_relevance!
nero_diagnostics
adapt_leak!
```

## `LobeState`

```julia
LobeState(last_spike_rate::Float32, output::Vector{Float32})
LobeState(n_out::Int)
```

Compact per-component state consumed by `update_relevance!`.

Fields:
- `last_spike_rate`: normalized activity estimate in `[0, 1]`
- `output`: readout vector used for EMA/surprise tracking

Notes:
- `output` width should match the orchestrator's `n_out`
- `LobeState(n_out)` creates a zeroed placeholder

## `NeroOrchestrator`

```julia
NeroOrchestrator(; n_lobes=4, n_out=16, lobe_names=NERO_DEFAULT_LOBE_NAMES)
```

Mutable routing state.

Important fields:
- `routing_weights`
- `readout_ema`
- `spike_density`
- `prev_routing_weights`
- `prev_relevance`
- `surprise`
- `tick_count`

Notes:
- the hot path is preallocated and in-place
- default names are historical/example defaults, not required semantics
- callers can provide custom `lobe_names`

## `update_relevance!`

```julia
update_relevance!(nero::NeroOrchestrator, lobes::Vector{LobeState})
```

Per-tick routing update.

Behavior:
- increments `tick_count`
- updates per-component EMA state
- computes surprise and momentum
- applies inhibition
- updates `routing_weights`

Expected caller guarantees:
- `length(lobes) == nero.n_lobes`
- each `lobe.output` matches `nero.n_out`
- spike-rate values are already normalized to a meaningful scale for the caller

## `nero_diagnostics`

```julia
nero_diagnostics(nero::NeroOrchestrator)::String
```

Returns a short string summary including:
- current tick
- per-component routing weights
- dominant component
- surprise scores

Useful for logs, debugging, and lightweight monitoring.

## `adapt_leak!`

```julia
adapt_leak!(leak_rate::Ref{Float32}, fan_speed_perc::Float32)
```

Small helper that maps a fan-speed-like stress signal in `[0, 100]` to a leak-rate range.

Notes:
- this function is optional convenience logic
- it is not required for the core routing algorithm
- callers that use different stress semantics may want a different adapter layer

## Known API design limitations

These are current limitations, not hidden behavior:

- the package name is generalized, but some exported symbols still carry NERO naming
- no higher-level config object exists for the inhibition matrix or scoring constants
- defaults still imply a four-component layout
- there is not yet a first-class generic `ComponentState` / `RouterState` naming pass

That is part of the package's current stage: usable now, but not yet the final API shape.
