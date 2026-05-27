"""
    channel_index(labels, channels)

Convert channel specifications to channel indices.
"""
function channel_index(labels::AbstractVector{<:AbstractString}, channels::AbstractVector{<:AbstractString})
    indices = map(channels) do chan
        idx = findfirst(isequal(chan), labels)
        idx === nothing && error("Channel label $chan not found!")
        idx
    end
    return sort(unique(indices))
end

# Handle Integer arrays directly
function channel_index(labels::AbstractVector{<:AbstractString}, channels::AbstractVector{<:Integer})
    checkbounds(Bool, labels, channels) || error("Requested channel index out of bounds!")
    return sort(unique(channels))
end

# Convenience method for single inputs
channel_index(labels::AbstractVector{<:AbstractString}, channel::Union{AbstractString, Integer}) = channel_index(labels, [channel])
