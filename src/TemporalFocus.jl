"""
    TemporalFocus

Spike-driven relevance routing for modular neural systems.

TemporalFocus computes per-tick routing weights across component summaries using:
- spike density (α=0.50)
- manifold surprise via EMA deviation (β=0.35)
- routing momentum (γ=0.15)

The current package still exposes the historical NERO naming in parts of the API,
but the package boundary is intentionally narrow: it owns relevance routing, not a
full SNN runtime, training system, or hardware integration layer.
"""
module TemporalFocus

export LobeState, NeroOrchestrator, update_relevance!, nero_diagnostics, adapt_leak!

include("lobe.jl")
include("nero_orchestrator.jl")

end # module
