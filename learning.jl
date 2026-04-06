function stdp_update!(
    weights::AbstractMatrix,
    pre::SpikeTrain,
    post::SpikeTrain;
    τ::Real = 1.0f0,
    η::Real = 0.01f0,
)
    n_pre = size(weights, 1)
    n_post = size(weights, 2)
    η_f32 = Float32(η)

    @inbounds for pre_event in pre.events
        pre_id = _check_neuron_id(pre_event.neuron_id, n_pre, "pre")
        for post_event in post.events
            post_id = _check_neuron_id(post_event.neuron_id, n_post, "post")
            Δw = η_f32 * pre_event.value * post_event.value *
                 temporal_weight(post_event.t - pre_event.t, τ)
            weights[pre_id, post_id] += Δw
        end
    end

    return weights
end
