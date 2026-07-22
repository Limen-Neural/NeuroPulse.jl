# TemporalFocus interop contract

**Status:** frozen docs/contract (LIM-228 / GH#14)  
**Scope:** common data shapes at the package boundary — not new SNN types, not routing math.

This document freezes the compact interop shapes that callers and sibling systems
(including non-Julia sides) should use when feeding TemporalFocus and reading its
outputs. It describes what the package **owns** and what it **does not**.

> **Obsolete path:** `src/nero_orchestrator.jl` no longer exists. Routing state
> lives in `src/region_router.jl`; per-region summaries live in
> `src/activity_region.jl`. Prefer the generic names below. Legacy aliases
> (`LobeState`, `NeroOrchestrator`, …) remain for backward compatibility only.

---

## Ownership boundary

### What TemporalFocus owns

| Shape / symbol | Role |
|----------------|------|
| `ActivityRegion` | Compact per-region summary for one tick |
| `RegionRouter` | Mutable routing state (pre-allocated buffers) |
| `update_routing!` | In-place per-tick relevance update |
| `routing_diagnostics` | Lightweight string summary for logs |
| `adapt_leak!` | Optional stress → leak helper (not core routing) |

### What TemporalFocus does **not** own

- Spike **event lists** or full spike **trains**
- Neuron / synapse / membrane state
- Reservoir simulation or training loops
- Token embeddings, ANN/LLM adapters, or deployment supervision
- Hardware telemetry ingestion (callers reduce telemetry to compact rates)

Callers must reduce their internal state to the compact shapes below before
calling into TemporalFocus.

---

## Core shapes

### `ActivityRegion`

```julia
struct ActivityRegion
    last_spike_rate::Float32
    output::Vector{Float32}
end
```

| Field | Type | Contract |
|-------|------|----------|
| `last_spike_rate` | `Float32` | Normalised firing rate in **`[0, 1]`** for this region this tick |
| `output` | `Vector{Float32}` | Readout vector of length **`n_out`** (same `n_out` as the router) |

Constructor helper:

```julia
ActivityRegion(n_out::Int)  # zero rate, zero readout of length n_out
```

**Caller duties**

- Supply `last_spike_rate` already normalised to `[0, 1]` (package does not rescale Hz).
- Ensure `length(output) == router.n_out`.
- Prefer `Float32` end-to-end; mixed precision is not part of the contract.

**Legacy alias:** `LobeState === ActivityRegion`.

---

### `RegionRouter`

Mutable routing state. Pre-allocated at construction; the hot path of
`update_routing!` does no heap allocation on these fields.

| Field | Shape | Contract |
|-------|--------|----------|
| `n_regions` | `Int` | Number of regions |
| `n_out` | `Int` | Readout width per region |
| `region_names` | `Vector{String}` length `n_regions` | Human-readable labels |
| `adjacency_matrix` | `Matrix{Float32}` `n_regions × n_regions` | Binary edge **mask** (`> 0` enables inhibition); magnitude is not a continuous weight in the hot path |
| `routing_weights` | `Vector{Float32}` length `n_regions` | **Primary output**; sums to **~1** after each tick |
| `readout_ema` | `Matrix{Float32}` `n_regions × n_out` | Per-region EMA of readouts |
| `spike_density` | `Vector{Float32}` length `n_regions` | Last tick’s rates (copy of inputs) |
| `prev_routing_weights` | `Vector{Float32}` length `n_regions` | Momentum buffer; after a normal `update_routing!` call it equals the just-written `routing_weights` (not a preserved prior-tick snapshot for external readers) |
| `prev_relevance` | `Vector{Float32}` length `n_regions` | Scratch / last raw scores |
| `surprise` | `Vector{Float32}` length `n_regions` | Manifold surprise per region |
| `scratch` | `Vector{Float32}` length `n_out` | Hot-path scratch buffer |
| `tick_count` | `Int64` | Global tick counter |

Constructor:

```julia
RegionRouter(; n_regions=4, n_out=16, region_names=DEFAULT_REGION_NAMES)
```

Initial `routing_weights` are uniform (`1 / n_regions`).

**Legacy alias:** `NeroOrchestrator === RegionRouter`.

---

## Tick contract

```julia
update_routing!(router::RegionRouter, regions::Vector{ActivityRegion}) -> nothing
```

| Input | Requirement |
|-------|-------------|
| `regions` | `Vector{ActivityRegion}` with **`length(regions) == router.n_regions`** |
| each `regions[i].last_spike_rate` | `Float32` in `[0, 1]` |
| each `regions[i].output` | `Vector{Float32}` of length **`router.n_out`** |

| Output (in-place on `router`) | Contract |
|-------------------------------|----------|
| `router.routing_weights` | length `n_regions`, **positive** entries, **sum ≈ 1** (`MIN_SCORE` clamps pre-/mid-normalization scores only; final entries may fall below `MIN_SCORE` after re-normalization) |
| `router.surprise`, `router.spike_density`, … | updated diagnostics; readable after the call |
| return value | `nothing` (consume `routing_weights`, not a return vector) |

**Legacy alias:** `update_relevance! === update_routing!`.

This freeze does **not** change routing math (α/β/γ, EMA decay, inhibition, softmax).

---

## Numeric conventions (interop)

| Quantity | Convention |
|----------|------------|
| Element type for rates, weights, readouts, EMA | **`Float32`** |
| Spike / activity rates | **`[0, 1]`** (normalised by the caller) |
| `routing_weights` | length `n_regions`, sum **~1** (soft floor + renorm) |
| Readout length | **`n_out`** for every region |
| Time base | Caller-defined tick; package is tick-agnostic |

For non-Julia consumers (e.g. a Rust side): treat the boundary as arrays of `f32`
with the dimensions above. TemporalFocus never requires spike timestamps or event
lists at the API surface.

---

## Explicit non-shapes

The following are **not** package types and are **not** part of this freeze:

- Spike trains / event lists (`Vector` of times or `(neuron, t)` pairs)
- Full membrane or synapse tensors
- Shared “modulator” blobs beyond `ActivityRegion.output`
- Config objects for α/β/γ or the full inhibition matrix (constants live in source)

If a workflow needs those, they belong in the surrounding SNN/runtime package;
only the compact summaries cross into TemporalFocus.

---

## See also

- [`api.md`](api.md) — exported symbols and behavior notes
- [`overview.md`](overview.md) — architecture and intended usage
- Repository root README — “What TemporalFocus owns”
