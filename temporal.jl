@inline function temporal_weight(dt::Real, τ::Real)
    τ_f32 = Float32(τ)
    τ_f32 > 0f0 || throw(ArgumentError("τ must be positive"))
    return exp(-abs(Float32(dt)) / τ_f32)
end

function spike_attention_temporal(
    q::SpikeTrain,
    k::SpikeTrain,
    v::AbstractMatrix;
    τ::Real = 1.0f0,
)
    n = _check_positive_rows(v)
    attention = zeros(Float32, n)

    @inbounds for qe in q.events
        qid = _check_neuron_id(qe.neuron_id, n, "query")
        for ke in k.events
            if qid == ke.neuron_id
                attention[qid] += qe.value * ke.value * temporal_weight(qe.t - ke.t, τ)
            end
        end
    end

    return _project_attention(attention, v)
end
