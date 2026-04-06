@inline function _check_positive_rows(v::AbstractMatrix)
    nrows = size(v, 1)
    nrows > 0 || throw(ArgumentError("value matrix must have at least one row"))
    return nrows
end

@inline function _check_neuron_id(neuron_id::Int, upper::Int, label::AbstractString)
    1 <= neuron_id <= upper ||
        throw(ArgumentError("$(label) neuron_id $(neuron_id) is outside valid range 1:$(upper)"))
    return neuron_id
end

@inline function _apply_readout(weights::AbstractVector{<:Real}, readout::AbstractMatrix)
    length(weights) == size(readout, 1) ||
        throw(DimensionMismatch("attention weights length must match readout rows"))
    return transpose(readout) * weights
end

function spike_attention_discrete(
    source_spikes::SpikeTrain,
    context_spikes::SpikeTrain,
    readout::AbstractMatrix,
)
    n = _check_positive_rows(readout)
    attention = zeros(Float32, n)

    @inbounds for source_event in source_spikes.events
        source_id = _check_neuron_id(source_event.neuron_id, n, "source")
        for context_event in context_spikes.events
            if source_id == context_event.neuron_id
                attention[source_id] += source_event.value * context_event.value
            end
        end
    end

    return _apply_readout(attention, readout)
end
