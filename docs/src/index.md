# TemporalFocus.jl

```@meta
CurrentModule = TemporalFocus
```

Spike-driven relevance routing for modular neural systems.

TemporalFocus computes per-tick routing weights across activity-region summaries from:

- spike density
- readout surprise relative to an exponential moving average
- routing momentum
- lateral inhibition between components

The package boundary is intentionally narrow: it owns relevance routing, not a full SNN
runtime, training system, or hardware integration layer.

## Documentation

```@contents
Pages = ["overview.md", "api.md", "roadmap.md"]
Depth = 2
```

## Quick start

```julia
using TemporalFocus

router = RegionRouter(
    n_regions = 4,
    n_out = 8,
    region_names = ["sensor", "reservoir", "memory", "decoder"],
)

regions = [ActivityRegion(8) for _ in 1:4]
# fill region spike rates / outputs, then:
update_routing!(router, regions)
router.routing_weights
```

## Package

The Julia package name is **TemporalFocus**. The GitHub repository is still named
[NeuroPulse.jl](https://github.com/Limen-Neural/NeuroPulse.jl).

```@docs
TemporalFocus
```
