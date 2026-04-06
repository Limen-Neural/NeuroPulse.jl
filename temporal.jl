@inline function temporal_weight(dt::Real, τ::Real)
    τ_f32 = Float32(τ)
    τ_f32 > 0f0 || throw(ArgumentError("τ must be positive"))
    return exp(-abs(Float32(dt)) / τ_f32)
end

function spike_attention_temporal(
    source_spikes::SpikeTrain,
    context_spikes::SpikeTrain,
    readout::AbstractMatrix;
    τ::Real = 1.0f0,
)
    n = _check_positive_rows(readout)
    attention = zeros(Float32, n)

    @inbounds for source_event in source_spikes.events
        source_id = _check_neuron_id(source_event.neuron_id, n, "source")
        for context_event in context_spikes.events
            if source_id == context_event.neuron_id
                attention[source_id] += source_event.value * context_event.value *
                                        temporal_weight(source_event.t - context_event.t, τ)
            end
        end
    end

    return _apply_readout(attention, readout)
end
