# TemporalFocus overview

TemporalFocus.jl is a focused routing library for modular neural systems.

Its job is simple: given a set of component summaries for the current tick, compute a
normalized relevance vector that can be used by a caller to prioritize which components
should receive attention, compute budget, or downstream routing weight.

## Mental model

Each component contributes two signals:

- activity now: how much it is firing this tick
- change now: how much its readout changed relative to recent history

TemporalFocus combines those with routing momentum, applies lateral inhibition, and emits a
new routing distribution.

## Data flow

1. The caller constructs one `LobeState` per component.
2. Each `LobeState` provides:
   - `last_spike_rate`
   - `output`
3. `update_relevance!` updates the orchestrator's EMA, surprise scores, and routing weights.
4. The caller consumes `routing_weights`.

## Why the API is so small

This package is intentionally not a full runtime. It is an extracted decision layer.
That keeps it easy to embed in:

- SNN experiments
- ANN/SNN hybrids
- reservoir pipelines
- hardware-aware control loops
- research prototypes that need a compact routing heuristic

## Intended usage pattern

TemporalFocus works best when another system already owns:

- neuron updates
- reservoir stepping
- feature extraction
- telemetry ingestion
- scheduling/execution

That system should reduce its internal state to a small component summary and call
TemporalFocus as a pure routing stage.

## Boundary guidance

Good fits for TemporalFocus:

- deciding which reservoir/readout path is most relevant this tick
- reweighting modules in a modular neural pipeline
- prioritizing component execution from spike-derived signals
- monitoring surprise and dominance across component groups

Poor fits for TemporalFocus:

- simulating neuron membrane equations
- reading exchange feeds or hardware sensors directly
- running training loops
- acting as a general-purpose LLM orchestration framework
- owning deployment/runtime concerns

## Current rough edges

The package still carries some historical assumptions:

- NERO terminology is still part of the API
- default lobe names reflect an older four-part example layout
- `adapt_leak!` is currently framed around fan-speed-like stress input
- docs and naming are cleaner than before, but the package is still early

## Practical interpretation for users

Treat TemporalFocus as a reusable routing kernel, not as a finished platform.
It is already useful for experiments, but it still needs substantial cleanup and design
work before it reaches the broader long-term state rmems wants.
