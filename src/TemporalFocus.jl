# SPDX-License-Identifier: MIT OR Apache-2.0
"""
    TemporalFocus

Spike-driven relevance routing for modular neural systems.

TemporalFocus computes per-tick routing weights across activity region summaries using:
- spike density (α=0.50)
- manifold surprise via EMA deviation (β=0.35)
- routing momentum (γ=0.15)

The package boundary is intentionally narrow: it owns relevance routing, not a
full SNN runtime, training system, or hardware integration layer.

## Generic API (preferred)

Use `ActivityRegion`, `RegionRouter`, `update_routing!`, and `routing_diagnostics`.

## Legacy API (backward compatible)

`LobeState`, `NeroOrchestrator`, `update_relevance!`, and `nero_diagnostics` are
aliases that map to the generic types. They will continue to work but new code
should prefer the generic names.
"""
module TemporalFocus

# ── Generic API (preferred) ───────────────────────────────────────────────────

include("activity_region.jl")
include("region_router.jl")

# ── Exports ───────────────────────────────────────────────────────────────────

# Generic API (preferred)
export ActivityRegion, RegionRouter, update_routing!, routing_diagnostics, adapt_leak!
export save_state, load_state!, load_state

# Backward-compatible type aliases
const LobeState = ActivityRegion
const NeroOrchestrator = RegionRouter

# Backward-compatible function aliases (const for type stability)
const update_relevance! = update_routing!
const nero_diagnostics = routing_diagnostics

export LobeState, NeroOrchestrator, update_relevance!, nero_diagnostics

end # module
