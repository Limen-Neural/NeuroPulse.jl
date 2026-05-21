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
