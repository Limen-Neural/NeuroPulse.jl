function spike_attention_continuous(
    buffer_q::TemporalBuffer,
    buffer_k::TemporalBuffer,
    v::AbstractMatrix;
    τ::Real = 1.0f0,
)
    n = _check_positive_rows(v)
    attention = zeros(Float32, n)
    window = min(buffer_q.window, buffer_k.window)

    @inbounds for qe in buffer_q.events
        qid = _check_neuron_id(qe.neuron_id, n, "query")
        for ke in buffer_k.events
            if qid == ke.neuron_id
                dt = qe.t - ke.t
                if abs(dt) <= window
                    attention[qid] += qe.value * ke.value * temporal_weight(dt, τ)
                end
            end
        end
    end

    return _project_attention(attention, v)
end
