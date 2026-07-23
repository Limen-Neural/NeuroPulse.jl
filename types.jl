# SPDX-License-Identifier: MIT OR Apache-2.0

"""
    SpikeEvent(neuron_id, t, value=1.0f0)

A single spike event at a neuron.

# Arguments
- `neuron_id::Integer`: 1-based neuron index that produced the spike
- `t::Real`: spike time (stored as `Float32`)
- `value::Real`: spike amplitude or weight (default `1.0f0`, stored as `Float32`)

# Fields
- `neuron_id::Int`
- `t::Float32`
- `value::Float32`
"""
struct SpikeEvent
    neuron_id::Int
    t::Float32
    value::Float32
end

SpikeEvent(neuron_id::Integer, t::Real, value::Real = 1.0f0) =
    SpikeEvent(Int(neuron_id), Float32(t), Float32(value))

"""
    SpikeTrain(events=SpikeEvent[])

An unordered collection of [`SpikeEvent`](@ref)s.

# Arguments
- `events`: vector of `SpikeEvent` (copied into a `Vector{SpikeEvent}`)

# Fields
- `events::Vector{SpikeEvent}`
"""
struct SpikeTrain
    events::Vector{SpikeEvent}
end

SpikeTrain() = SpikeTrain(SpikeEvent[])
SpikeTrain(events::AbstractVector{<:SpikeEvent}) = SpikeTrain(collect(events))

"""
    TemporalBuffer(window, events=SpikeEvent[])

A sliding temporal window of spike events.

Events older than `window` relative to a reference time can be removed with
[`prune!`](@ref).

# Arguments
- `window::Real`: retention window length (stored as `Float32`)
- `events`: initial events (copied into a `Vector{SpikeEvent}`)

# Fields
- `window::Float32`
- `events::Vector{SpikeEvent}`
"""
struct TemporalBuffer
    window::Float32
    events::Vector{SpikeEvent}
end

TemporalBuffer(window::Real, events::AbstractVector{<:SpikeEvent} = SpikeEvent[]) =
    TemporalBuffer(Float32(window), collect(events))

Base.isempty(train::SpikeTrain) = isempty(train.events)
Base.isempty(buffer::TemporalBuffer) = isempty(buffer.events)

"""
    prune!(buffer::TemporalBuffer, current_time) -> TemporalBuffer

Remove events from `buffer` that fall outside the retention window.

Keeps only events satisfying `(current_time - event.t) <= buffer.window`.
Mutates `buffer.events` in place and returns `buffer`.

# Arguments
- `buffer::TemporalBuffer`: buffer to prune
- `current_time::Real`: reference time (converted to `Float32`)

# Returns
- the same `buffer` after pruning
"""
function prune!(buffer::TemporalBuffer, current_time::Real)
    current_time_f32 = Float32(current_time)
    filter!(event -> (current_time_f32 - event.t) <= buffer.window, buffer.events)
    return buffer
end
