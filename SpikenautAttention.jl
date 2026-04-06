module SpikenautAttention

export SpikeEvent, SpikeTrain, TemporalBuffer
export prune!
export temporal_weight
export spike_attention_discrete
export spike_attention_temporal
export spike_attention_continuous
export normalize_l1!, normalize_max!
export stdp_update!

include("types.jl")
include("discrete.jl")
include("temporal.jl")
include("continuous.jl")
include("normalization.jl")
include("learning.jl")

end
