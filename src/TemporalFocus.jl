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

# ── Backward-compatible legacy includes ───────────────────────────────────────

# lobe.jl defines LobeState — but since ActivityRegion is structurally identical,
# we skip re-defining it and just create an alias.
# nero_orchestrator.jl defines NeroOrchestrator — same situation.
# We include them for their adapt_leak! (already in activity_region.jl) and for
# any code that references the NERO_* constants.

# ── Exports ───────────────────────────────────────────────────────────────────

# Generic API (preferred)
export ActivityRegion, RegionRouter, update_routing!, routing_diagnostics, adapt_leak!

# Backward-compatible aliases
const LobeState = ActivityRegion
const NeroOrchestrator = RegionRouter
update_relevance! = update_routing!
nero_diagnostics = routing_diagnostics

export LobeState, NeroOrchestrator, update_relevance!, nero_diagnostics

end # module
