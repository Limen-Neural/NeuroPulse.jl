<p align="center">
  <img src="docs/logo.png" width="220" alt="TemporalFocus">
</p>

<h1 align="center">TemporalFocus.jl</h1>
<p align="center">Spike-driven relevance routing for modular neural systems</p>

<p align="center">
  <img src="https://img.shields.io/badge/language-Julia-9558B2" alt="Julia">
  <img src="https://img.shields.io/badge/license-MIT%2FApache--2.0-blue" alt="MIT OR Apache-2.0">
</p>

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://limen-neural.github.io/NeuroPulse.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://limen-neural.github.io/NeuroPulse.jl/dev)

---

TemporalFocus.jl is a small Julia library for computing per-component relevance scores from
spike activity and readout change over time. The core abstraction is a routing loop that
updates component weights from:

- spike density
- readout surprise relative to an exponential moving average
- routing momentum
- lateral inhibition between components

The library is intentionally narrow. It does not try to be a full SNN runtime, an LLM
integration layer, or a hardware supervisor.

## Project status

TemporalFocus is an extracted, early-stage library. It is useful today, but it still needs a
lot of work before it reaches the broader long-term shape rmems wants for it.

What this means in practice:

- the current API is small and focused
- several defaults still reflect the original research/runtime context
- documentation and boundaries are improving, but the package is not yet the final form
- downstream integrations should treat this as an evolving library rather than a finished platform

## What TemporalFocus owns

TemporalFocus owns spike-driven relevance routing logic:

- `ActivityRegion` as a compact per-region summary (`Float32` rate in `[0,1]`, readout of length `n_out`)
- `RegionRouter` as the mutable routing state (`routing_weights` length `n_regions`, sum ~1)
- `update_routing!` as the per-tick routing update
- `routing_diagnostics` for lightweight inspection/logging
- `adapt_leak!` as a small optional helper for stress-aware leak adaptation

The frozen interop shapes (and what the package deliberately does **not** own — e.g. spike
event lists / full trains) are documented in [`docs/interop.md`](docs/interop.md).

## What TemporalFocus does not own

TemporalFocus does not own:

- spike event lists or full spike trains
- full neuron or reservoir simulation
- training loops or plasticity pipelines
- token embeddings or transformer execution
- hardware telemetry ingestion
- deployment/runtime supervision
- model-specific ANN/LLM adapters

If a workflow needs those pieces, they should live in surrounding libraries or applications
that feed compact readouts into TemporalFocus.

## Installation

```julia
using Pkg
Pkg.add("TemporalFocus")
```

## Quick start

```julia
using TemporalFocus

router = RegionRouter(
    n_regions = 4,
    n_out = 8,
    region_names = ["sensor", "reservoir", "memory", "decoder"],
)

regions = [
    ActivityRegion(0.82f0, Float32[0.9, 0.7, 0.2, 0.1, 0.0, 0.1, 0.3, 0.5]),
    ActivityRegion(0.28f0, Float32[0.3, 0.2, 0.1, 0.0, 0.0, 0.0, 0.2, 0.2]),
    ActivityRegion(0.41f0, Float32[0.4, 0.6, 0.5, 0.2, 0.1, 0.1, 0.0, 0.1]),
    ActivityRegion(0.12f0, Float32[0.1, 0.1, 0.0, 0.0, 0.4, 0.6, 0.8, 0.9]),
]

update_routing!(router, regions)

routing_weights = router.routing_weights
println(routing_weights)
println(routing_diagnostics(router))
```

## Examples

Worked examples live in [`examples/`](examples/):

- [`examples/three_region.jl`](examples/three_region.jl) — minimal 3-region layout
- [`examples/six_region.jl`](examples/six_region.jl) — larger layout with custom region names
- [`examples/reservoir_integration.jl`](examples/reservoir_integration.jl) — pattern for feeding compact reservoir readouts into TemporalFocus

Run any example from the repository root:

```bash
julia --project=. examples/three_region.jl
```

### Legacy API

The old NERO/lobe names still work as backward-compatible aliases:

```julia
# These are equivalent:
LobeState == ActivityRegion
NeroOrchestrator == RegionRouter
update_relevance! == update_routing!
nero_diagnostics == routing_diagnostics
```

## Core routing rule

At each tick, TemporalFocus computes a raw score for each component:

```
score_i = α · density_i + β · surprise_i + γ · momentum_i
```

with:

- `density_i`: current normalized spike activity
- `surprise_i`: deviation from the component's EMA readout
- `momentum_i`: change in routing weight relative to the previous tick

The raw scores are then:

1. reduced by cross-component inhibition
2. clamped with a floor so components do not go fully silent
3. normalized with a softmax-like pass to produce routing weights that sum to 1

## Public API

```julia
ActivityRegion(last_spike_rate::Float32, output::Vector{Float32})
ActivityRegion(n_out::Int)

RegionRouter(; n_regions=4, n_out=16, region_names=DEFAULT_REGION_NAMES)

update_routing!(router::RegionRouter, regions::Vector{ActivityRegion})
routing_diagnostics(router::RegionRouter)
adapt_leak!(leak_rate::Ref{Float32}, fan_speed_perc::Float32)
```

Legacy aliases (`LobeState`, `NeroOrchestrator`, `update_relevance!`, `nero_diagnostics`)
resolve to the same types/functions; use the preferred names above for new code.

## Default assumptions and current limitations

A few defaults still reflect the package's original extraction context:

- the default lobe names are `Attention`, `FFN`, `Memory`, and `Output`
- the default inhibition matrix is tuned for a 4-component example layout
- `adapt_leak!` assumes a fan-speed-like stress signal in `[0, 100]`
- the package currently exposes NERO terminology directly in type/function names

Those defaults are serviceable, but they are not the final abstraction boundary.

## Documentation

- [Stable docs](https://limen-neural.github.io/NeuroPulse.jl/stable) (created on first version tag)
- [Dev docs](https://limen-neural.github.io/NeuroPulse.jl/dev) (updates from `main`)

Source markdown lives in `docs/` (Documenter pages under `docs/src/`):

- `docs/overview.md` / `docs/src/overview.md` — architecture, scope, and intended usage
- `docs/api.md` / `docs/src/api.md` — exported types/functions and behavior notes
- `docs/interop.md` — frozen data-shape / interop contract (rates, readouts, routing weights)
- `docs/roadmap.md` / `docs/src/roadmap.md` — gaps, next cleanup targets, and candid project status

Build locally with:

```bash
julia --project=docs -e 'using Pkg; Pkg.develop(path="."); Pkg.instantiate()'
julia --project=docs docs/make.jl
```

## Migration note

This repository was renamed from `NeuroPulse.jl` (and earlier `SpikenautAttention.jl` or `SpikenautNero.jl`) to `TemporalFocus.jl`.

Migration steps for downstream users:

- replace `Pkg.add("NeuroPulse")` (or `SpikenautAttention`) with `Pkg.add("TemporalFocus")`
- replace `using NeuroPulse` (or `using SpikenautAttention`) with `using TemporalFocus`
- update any package metadata or examples that still reference the old name

The NERO algorithm name remains in the current public API via `NeroOrchestrator` and
`nero_diagnostics`, but the package identity is now `TemporalFocus`.

## Development

Run tests with:

```bash
julia --project -e 'using Pkg; Pkg.instantiate(); Pkg.test()'
```

## License

This project is licensed under either of

- Apache License, Version 2.0 ([LICENSE-APACHE-2.0](LICENSE-APACHE-2.0) or <http://www.apache.org/licenses/LICENSE-2.0>)
- MIT license ([LICENSE-MIT](LICENSE-MIT) or <http://opensource.org/licenses/MIT>)

at your option.

Contributions intentionally submitted for inclusion in this package by you, as
defined in the Apache-2.0 license, shall be dual-licensed as above, without any
additional terms or conditions.
