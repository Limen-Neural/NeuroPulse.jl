# SPDX-License-Identifier: MIT OR Apache-2.0

"""
    TemporalFocus

Pure spike-native temporal attention kernel for the Spikenaut ecosystem.

This module provides coincidence-based and temporally decayed spike interaction,
recency-weighted temporal attention, attention normalization, and readout
application over spike-derived weights.

# Exports
- [`SpikeEvent`](@ref), [`SpikeTrain`](@ref), [`TemporalBuffer`](@ref) — spike data types
- [`prune!`](@ref) — in-place temporal buffer pruning
- [`temporal_weight`](@ref) — exponential recency weighting
- [`spike_attention_discrete`](@ref), [`spike_attention_temporal`](@ref),
  [`spike_attention_continuous`](@ref) — attention kernels
- [`normalize_l1!`](@ref), [`normalize_max!`](@ref) — in-place weight normalization

All spike values and temporal quantities use `Float32`.
"""
module TemporalFocus

export SpikeEvent, SpikeTrain, TemporalBuffer
export prune!
export temporal_weight
export spike_attention_discrete
export spike_attention_temporal
export spike_attention_continuous
export normalize_l1!, normalize_max!

include("types.jl")
include("discrete.jl")
include("temporal.jl")
include("continuous.jl")
include("normalization.jl")

end
