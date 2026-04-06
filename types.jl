struct SpikeEvent
    neuron_id::Int
    t::Float32
    value::Float32
end

SpikeEvent(neuron_id::Integer, t::Real, value::Real = 1.0f0) =
    SpikeEvent(Int(neuron_id), Float32(t), Float32(value))

struct SpikeTrain
    events::Vector{SpikeEvent}
end

SpikeTrain() = SpikeTrain(SpikeEvent[])
SpikeTrain(events::AbstractVector{<:SpikeEvent}) = SpikeTrain(collect(events))

struct TemporalBuffer
    window::Float32
    events::Vector{SpikeEvent}
end

TemporalBuffer(window::Real, events::AbstractVector{<:SpikeEvent} = SpikeEvent[]) =
    TemporalBuffer(Float32(window), collect(events))

function prune!(buffer::TemporalBuffer, current_time::Real)
    current_time_f32 = Float32(current_time)
    filter!(event -> (current_time_f32 - event.t) <= buffer.window, buffer.events)
    return buffer
end
