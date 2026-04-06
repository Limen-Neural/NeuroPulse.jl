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

@inline function _project_attention(weights::AbstractVector{<:Real}, values::AbstractMatrix)
    length(weights) == size(values, 1) ||
        throw(DimensionMismatch("attention weights length must match value rows"))
    return transpose(values) * weights
end

function spike_attention_discrete(
    q::SpikeTrain,
    k::SpikeTrain,
    v::AbstractMatrix,
)
    n = _check_positive_rows(v)
    attention = zeros(Float32, n)

    @inbounds for qe in q.events
        qid = _check_neuron_id(qe.neuron_id, n, "query")
        for ke in k.events
            if qid == ke.neuron_id
                attention[qid] += qe.value * ke.value
            end
        end
    end

    return _project_attention(attention, v)
end
