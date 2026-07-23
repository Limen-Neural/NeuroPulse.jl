# TemporalFocus API notes

For the frozen interop data-shape contract (Float32 rates in `[0,1]`, readout length
`n_out`, `routing_weights` length `n_regions` summing ~1, no owned spike trains), see
[`interop.md`](interop.md).

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
- `LobeState` is a constant alias of `ActivityRegion`

## `RegionRouter` / `NeroOrchestrator`

```julia
RegionRouter(; n_regions=4, n_out=16, region_names=DEFAULT_REGION_NAMES,
               inhibition_matrix=nothing)
```

Mutable routing state. `NeroOrchestrator` is a constant alias of `RegionRouter`
(same constructor keywords — there is no `n_lobes` / `lobe_names` kwarg).

Important fields:
- `n_regions`, `n_out`
- `inhibition_matrix` — `n_regions × n_regions` lateral inhibition weights
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
- if `inhibition_matrix` is `nothing`, a default matrix is built for `n_regions`
  (`INHIBIT[1:n,1:n]` when `n ≤ 4`; scaled lateral matrix when `n > 4`); a custom
  matrix must be `n_regions × n_regions`

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
adapt_leak!(leak_rate::Ref{Float32}, stress::Real;
            min_leak::Real=0.01f0,
            max_leak::Real=0.25f0,
            stress_adapter=nothing)
```

Optional helper that maps a generic stress signal to a leak-rate range.
The second argument is `Real` (not only `Float32`) so ordinary numeric literals work.

Default adapter: `stress` is percent-scale in `[0, 100]` → unit interval, then
lerped between `min_leak` and `max_leak`. Pass `stress_adapter` to map any other
stress domain into `[0, 1]` first.

Notes:
- this function is optional convenience logic
- it is not required for the core routing algorithm
- custom `stress_adapter` is preferred when stress is not percent-scale

## Known API design limitations

These are current limitations, not hidden behavior:

- the package name is generalized (`TemporalFocus`); some exported symbols still carry NERO naming
- scoring constants (α/β/γ, EMA decay, floors) remain module-level globals (no `RoutingConfig` on this branch)
- defaults still imply a four-component example layout for names / historical `INHIBIT`
- inhibition is configurable via `RegionRouter(; inhibition_matrix=...)` (see field notes above)
- there is not yet a first-class generic `ComponentState` / `RouterState` naming pass

That is part of the package's current stage: usable now, but not yet the final API shape.
