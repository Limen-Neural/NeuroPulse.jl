function spike_attention_continuous(
    source_buffer::TemporalBuffer,
    context_buffer::TemporalBuffer,
    readout::AbstractMatrix;
    τ::Real = 1.0f0,
)
    n = _check_positive_rows(readout)
    attention = zeros(Float32, n)
    window = min(source_buffer.window, context_buffer.window)

    @inbounds for source_event in source_buffer.events
        source_id = _check_neuron_id(source_event.neuron_id, n, "source")
        for context_event in context_buffer.events
            if source_id == context_event.neuron_id
                dt = source_event.t - context_event.t
                if abs(dt) <= window
                    attention[source_id] += source_event.value * context_event.value *
                                            temporal_weight(dt, τ)
                end
            end
        end
    end

    return _apply_readout(attention, readout)
end
