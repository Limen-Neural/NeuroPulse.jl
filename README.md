<p align="center">
  <img src="docs/logo.png" width="220" alt="NeuroPulse">
</p>

<h1 align="center">NeuroPulse.jl</h1>
<p align="center">Spike-driven relevance routing for modular neural systems</p>

<p align="center">
  <img src="https://img.shields.io/badge/language-Julia-9558B2" alt="Julia">
  <img src="https://img.shields.io/badge/license-GPL--3.0-orange" alt="GPL-3.0">
</p>

---

NeuroPulse.jl is a small Julia library for computing per-component relevance scores from
spike activity and readout change over time. The core abstraction is a routing loop that
updates component weights from:

- spike density
- readout surprise relative to an exponential moving average
- routing momentum
- lateral inhibition between components

The library is intentionally narrow. It does not try to be a full SNN runtime, an LLM
integration layer, or a hardware supervisor.

## Project status

NeuroPulse is an extracted, early-stage library. It is useful today, but it still needs a
lot of work before it reaches the broader long-term shape rmems wants for it.

What this means in practice:

- the current API is small and focused
- several defaults still reflect the original research/runtime context
- documentation and boundaries are improving, but the package is not yet the final form
- downstream integrations should treat this as an evolving library rather than a finished platform

## What NeuroPulse owns

NeuroPulse owns spike-driven relevance routing logic:

- `LobeState` as a compact per-component summary
- `NeroOrchestrator` as the mutable routing state
- `update_relevance!` as the per-tick routing update
- `nero_diagnostics` for lightweight inspection/logging
- `adapt_leak!` as a small optional helper for stress-aware leak adaptation

## What NeuroPulse does not own

NeuroPulse does not own:

- full neuron or reservoir simulation
- training loops or plasticity pipelines
- token embeddings or transformer execution
- hardware telemetry ingestion
- deployment/runtime supervision
- model-specific ANN/LLM adapters

If a workflow needs those pieces, they should live in surrounding libraries or applications
that feed compact readouts into NeuroPulse.

## Installation

```julia
using Pkg
Pkg.add("NeuroPulse")
```

## Quick start

```julia
using NeuroPulse

orch = NeroOrchestrator(
    n_lobes = 4,
    n_out = 8,
    lobe_names = ["sensor", "reservoir", "memory", "decoder"],
)

lobes = [
    LobeState(0.82f0, Float32[0.9, 0.7, 0.2, 0.1, 0.0, 0.1, 0.3, 0.5]),
    LobeState(0.28f0, Float32[0.3, 0.2, 0.1, 0.0, 0.0, 0.0, 0.2, 0.2]),
    LobeState(0.41f0, Float32[0.4, 0.6, 0.5, 0.2, 0.1, 0.1, 0.0, 0.1]),
    LobeState(0.12f0, Float32[0.1, 0.1, 0.0, 0.0, 0.4, 0.6, 0.8, 0.9]),
]

update_relevance!(orch, lobes)

routing_weights = orch.routing_weights
println(routing_weights)
println(nero_diagnostics(orch))
```

## Core routing rule

At each tick, NeuroPulse computes a raw score for each component:

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
LobeState(last_spike_rate::Float32, output::Vector{Float32})
LobeState(n_out::Int)

NeroOrchestrator(; n_lobes=4, n_out=16, lobe_names=NERO_DEFAULT_LOBE_NAMES)

update_relevance!(nero::NeroOrchestrator, lobes::Vector{LobeState})
nero_diagnostics(nero::NeroOrchestrator)
adapt_leak!(leak_rate::Ref{Float32}, fan_speed_perc::Float32)
```

## Default assumptions and current limitations

A few defaults still reflect the package's original extraction context:

- the default lobe names are `Attention`, `FFN`, `Memory`, and `Output`
- the default inhibition matrix is tuned for a 4-component example layout
- `adapt_leak!` assumes a fan-speed-like stress signal in `[0, 100]`
- the package currently exposes NERO terminology directly in type/function names

Those defaults are serviceable, but they are not the final abstraction boundary.

## Documentation

Additional docs live in `docs/`:

- `docs/overview.md` — architecture, scope, and intended usage
- `docs/api.md` — exported types/functions and behavior notes
- `docs/roadmap.md` — gaps, next cleanup targets, and candid project status

## Migration note

This repository was renamed from `SpikenautNero.jl` to `NeuroPulse.jl`.

Migration steps for downstream users:

- replace `Pkg.add("SpikenautNero")` with `Pkg.add("NeuroPulse")`
- replace `using SpikenautNero` with `using NeuroPulse`
- update any package metadata or examples that still reference the old name

The NERO algorithm name remains in the current public API via `NeroOrchestrator` and
`nero_diagnostics`, but the package identity is now `NeuroPulse`.

## Development

Run tests with:

```bash
julia --project -e 'using Pkg; Pkg.instantiate(); Pkg.test()'
```

## License

GPL-3.0-or-later
