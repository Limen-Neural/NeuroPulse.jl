function normalize_l1!(weights::AbstractVector{<:AbstractFloat})
    total = sum(weights)
    if total > zero(total)
        weights ./= total
    end
    return weights
end

function normalize_max!(weights::AbstractVector{<:AbstractFloat})
    peak = maximum(weights)
    if peak > zero(peak)
        weights ./= peak
    end
    return weights
end
