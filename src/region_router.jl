# SPDX-License-Identifier: MIT OR Apache-2.0
# region_router.jl — Generic region-based relevance routing
#
# Computes per-tick routing weights across activity regions using:
#
#   1. Spike Density  — normalised firing rate of the region (0..1).
#      A region that is firing actively is "engaged" with the current regime.
#
#   2. Manifold Surprise — how much the region's current readout deviates from its
#      recent exponential moving average (EMA).  High surprise → the region just
#      transitioned into a new attractor / regime.
#
# Final relevance = α × spike_density + β × manifold_surprise + γ × ema_momentum
# All scalars are Float32; no heap allocation in the hot path.

using LinearAlgebra: norm
using Printf

# ── Tuning Constants ──────────────────────────────────────────────────────────

const ALPHA = 0.50f0       # Weight: spike density contribution
const BETA = 0.35f0        # Weight: manifold surprise contribution
const GAMMA = 0.15f0       # Weight: readout EMA momentum
const EMA_DECAY = 0.05f0   # EMA smoothing factor (5% new estimate per tick)
const MIN_SCORE = 0.01f0   # Clamp: never let any region drop to zero relevance
const EPSILON = 1.0f-6     # Numerical stability floor for normalisation

# Backward-compatible aliases
const NERO_ALPHA = ALPHA
const NERO_BETA = BETA
const NERO_GAMMA = GAMMA
const NERO_EMA_DECAY = EMA_DECAY
const NERO_MIN_SCORE = MIN_SCORE
const NERO_EPSILON = EPSILON

# Default region names for the historical 4-component example layout.
# Callers should override these when modeling a different system boundary.
const DEFAULT_REGION_NAMES = ["Region1", "Region2", "Region3", "Region4"]
const NERO_DEFAULT_LOBE_NAMES = DEFAULT_REGION_NAMES

# Cross-region inhibition: lateral inhibition for winner-take-all routing.
# Layout: INHIBIT[from_region, to_region]. Higher values = stronger suppression.
const INHIBIT = Float32[
    0.0 0.08 0.05 0.02   # Region1 → {Region2, Region3, Region4}
    0.04 0.0 0.06 0.03   # Region2 → {Region1, Region3, Region4}
    0.02 0.03 0.0 0.05   # Region3 → {Region1, Region2, Region4}
    0.01 0.02 0.03 0.0   # Region4 → {Region1, Region2, Region3}
]
const NERO_INHIBIT = INHIBIT

# ── Router State ──────────────────────────────────────────────────────────────

"""
    RegionRouter

Holds all mutable state for per-tick relevance routing.
Pre-allocated at startup; the hot-path `update_routing!` does NO heap
allocation — all work is in-place on these fields.

Fields:
  n_regions        — number of regions (default 4)
  n_out            — readout width per region (default 16)
  region_names     — human-readable region labels
  adjacency_matrix — n_regions × n_regions directed adjacency weights
  routing_weights  — current routing weights vector (sums to 1.0)
  readout_ema      — per-region EMA of the readout (n_regions × n_out)
  spike_density    — current spike density per region
  prev_routing_weights — previous tick routing weights (for momentum)
  prev_relevance   — scratch buffer for raw relevance scores during computation (readable after tick)
  surprise         — manifold surprise score per region
  scratch          — reusable scratch buffer (n_out elements)
  tick_count       — global tick counter
"""
mutable struct RegionRouter
    n_regions::Int
    n_out::Int
    region_names::Vector{String}
    adjacency_matrix::Matrix{Float32}
    routing_weights::Vector{Float32}
    readout_ema::Matrix{Float32}
    spike_density::Vector{Float32}
    prev_routing_weights::Vector{Float32}
    prev_relevance::Vector{Float32}
    surprise::Vector{Float32}
    scratch::Vector{Float32}
    tick_count::Int64
end

"""
    RegionRouter(; n_regions=4, n_out=16, region_names=DEFAULT_REGION_NAMES) -> RegionRouter

Build the static region graph and pre-allocate all working buffers.
"""
function RegionRouter(;
    n_regions::Int = 4,
    n_out::Int = 16,
    region_names::Vector{String} = DEFAULT_REGION_NAMES,
)

    adjacency_matrix = zeros(Float32, n_regions, n_regions)
    for i = 1:n_regions, j = 1:n_regions
        i != j && (adjacency_matrix[i, j] = 1.0f0)
    end

    RegionRouter(
        n_regions,
        n_out,
        region_names,
        adjacency_matrix,
        fill(1.0f0 / n_regions, n_regions),
        zeros(Float32, n_regions, n_out),
        zeros(Float32, n_regions),
        fill(1.0f0 / n_regions, n_regions),
        zeros(Float32, n_regions),
        zeros(Float32, n_regions),
        zeros(Float32, n_out),
        Int64(0),
    )
end

# ── Core Update ───────────────────────────────────────────────────────────────

"""
    update_routing!(router, regions) -> nothing

Compute relevance scores for all regions from the current activity states.
`regions` is a `Vector{ActivityRegion}` — one per region.

The result is stored in `router.routing_weights` (n_regions × Float32).

Algorithm per region i:
  1. spike_density[i]  = regions[i].last_spike_rate
  2. readout_ema[i,:]  = (1-EMA_DECAY)×old_ema + EMA_DECAY×regions[i].output
  3. surprise[i]       = norm(readout_delta) / (norm(readout_ema) + ε)
  4. momentum[i]       = |routing_weights[i] - prev_routing_weights[i]|
  5. raw[i]            = α×density + β×surprise + γ×momentum

Cross-region inhibition:
  6. inhibited[i] = raw[i] - Σⱼ INHIBIT[j,i] × raw[j]

Softmax normalisation → sum(relevance) = 1.0, each ≥ MIN_SCORE.
"""
function update_routing!(router::RegionRouter, regions::Vector{ActivityRegion})
    router.tick_count += 1
    n = router.n_regions
    raw = router.prev_relevance   # reuse buffer (prev no longer needed this tick)

    # ── Stage 1-3: per-region signal collection ───────────────────────────
    for i = 1:n
        region = regions[i]

        # 1. Spike density
        spike_density = region.last_spike_rate

        # 2. Readout EMA update (in-place)
        copyto!(router.scratch, region.output)
        @views ema_row = router.readout_ema[i, :]
        ema_row .= (1.0f0 - EMA_DECAY) .* ema_row .+ EMA_DECAY .* router.scratch

        # 3. Manifold surprise: |new - ema| / (|ema| + ε)
        router.scratch .-= ema_row      # scratch ← delta
        delta_norm = norm(router.scratch)
        ema_norm = norm(ema_row) + EPSILON
        router.surprise[i] = delta_norm / ema_norm

        # 4. Momentum
        momentum = abs(router.routing_weights[i] - router.prev_routing_weights[i])

        # 5. Raw score
        raw[i] = ALPHA * spike_density + BETA * router.surprise[i] + GAMMA * momentum
    end

    # ── Stage 4: cross-region graph inhibition ────────────────────────────
    inhibited = router.routing_weights
    for dst = 1:n
        inh_sum = 0.0f0
        for src = 1:n
            if router.adjacency_matrix[src, dst] > 0.0f0
                inh_sum += INHIBIT[src, dst] * raw[src]
            end
        end
        inhibited[dst] = max(raw[dst] - inh_sum, MIN_SCORE)
    end

    # ── Stage 5: softmax normalisation ────────────────────────────────────
    max_val = maximum(inhibited)
    s = 0.0f0
    for i = 1:n
        inhibited[i] = exp(inhibited[i] - max_val)
        s += inhibited[i]
    end
    inhibited ./= (s + EPSILON)

    for i = 1:n
        if inhibited[i] < MIN_SCORE
            inhibited[i] = MIN_SCORE
        end
    end
    inhibited ./= (sum(inhibited) + EPSILON)

    copyto!(router.prev_routing_weights, router.routing_weights)
    return nothing
end

# ── Diagnostics ───────────────────────────────────────────────────────────────

"""
    routing_diagnostics(router::RegionRouter) -> String

One-line routing state summary for logging.
"""
function routing_diagnostics(router::RegionRouter)::String
    region_strs = [
        @sprintf("%s=%.2f", router.region_names[i], router.routing_weights[i]) for
        i = 1:router.n_regions
    ]
    dominant = argmax(router.routing_weights)
    surprise_str =
        join([@sprintf("%.3f", router.surprise[i]) for i = 1:router.n_regions], ",")
    @sprintf(
        "[tick=%d] %s | dominant=%s | surprise=[%s]",
        router.tick_count,
        join(region_strs, " "),
        router.region_names[dominant],
        surprise_str
    )
end
