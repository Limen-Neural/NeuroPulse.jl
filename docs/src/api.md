# TemporalFocus API notes

This document summarizes the exported API as it exists today.

## Exported types and functions

Preferred (generic) names:

```julia
ActivityRegion
RegionRouter
update_routing!
routing_diagnostics
adapt_leak!
```

Legacy aliases (same objects):

```julia
LobeState          # === ActivityRegion
NeroOrchestrator   # === RegionRouter
update_relevance!  # === update_routing!
nero_diagnostics   # === routing_diagnostics
```

## `ActivityRegion` / `LobeState`

```julia
ActivityRegion(last_spike_rate::Float32, output::Vector{Float32})
ActivityRegion(n_out::Int)
```

Compact per-region state consumed by `update_routing!`.

Fields:
- `last_spike_rate`: normalized activity estimate in `[0, 1]`
- `output`: readout vector used for EMA/surprise tracking

Notes:
- `output` width should match the router's `n_out`
- `ActivityRegion(n_out)` creates a zeroed placeholder
- the type is immutable; rebuild or replace vector entries when rates/readouts change
- `LobeState` is a constant alias of `ActivityRegion`

## `RegionRouter` / `NeroOrchestrator`

```julia
RegionRouter(; n_regions=4, n_out=16, region_names=DEFAULT_REGION_NAMES)
```

Mutable routing state. `NeroOrchestrator` is a constant alias of `RegionRouter`
(same constructor keywords — there is no `n_lobes` / `lobe_names` kwarg).

Important fields:
- `n_regions`, `n_out`
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
- callers can provide custom `region_names`

## `update_routing!` / `update_relevance!`

```julia
update_routing!(router::RegionRouter, regions::Vector{ActivityRegion})
```

Per-tick routing update.

Behavior:
- increments `tick_count`
- updates per-region EMA state
- computes surprise and momentum
- applies inhibition
- updates `routing_weights`

Expected caller guarantees:
- `length(regions) == router.n_regions`
- each `region.output` matches `router.n_out`
- spike-rate values are already normalized to a meaningful scale for the caller

## `routing_diagnostics` / `nero_diagnostics`

```julia
routing_diagnostics(router::RegionRouter)::String
```

Returns a short string summary including:
- current tick
- per-region routing weights
- dominant region
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

- the package name is generalized (`TemporalFocus`); the GitHub repo is still `NeuroPulse.jl`
- legacy NERO aliases remain exported for compatibility
- no higher-level config object exists for the inhibition matrix or scoring constants
- defaults still imply a four-component layout

That is part of the package's current stage: usable now, but not yet the final API shape.
