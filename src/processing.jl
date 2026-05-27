"""
    trigger_info(fif)

Extract trigger information from FIF data by scanning the stimulus channel.
In FIF files, triggers are typically stored on a channel with `kind == 3` (FIFFV_STIM_CH) 
or named starting with "STI".
"""
function trigger_info(fif::FifData; stim_channel::Union{String, Nothing}="STI 014", verbose::Bool=true)
    # Prefer explicitly provided stim_channel
    stim_idx = nothing
    if stim_channel !== nothing
        stim_idx = findfirst(info -> info.ch_name == stim_channel, fif.header.ch_info)
    end
    
    # Fallback if not found or not provided
    if stim_idx === nothing
        stim_idx = findfirst(info -> info.kind == 3 || startswith(uppercase(info.ch_name), "STI"), fif.header.ch_info)
    end
    
    if stim_idx === nothing
        if verbose @info "No stimulus channel found. Triggers will be empty." end
        return FifTriggers(Int32[], Int[], Int[], OrderedDict{Int,Int}(), Matrix{Float64}(undef, 0, 2))
    end
    
    if verbose @info "Extracting triggers from channel: $(fif.header.ch_info[stim_idx].ch_name)" end
    
    # Raw trigger values (uncalibrated)
    info = fif.header.ch_info[stim_idx]
    
    # Reverse the calibration applied during read to get raw integer triggers
    raw_float = @views fif.data[stim_idx, :] ./ (info.range * info.cal)
    raw = Int32.(round.(raw_float))
    
    idx = Int[]
    val = Int[]
    count = OrderedDict{Int, Int}()
    
    # Detect rising edges (value changes from 0 or previous to new non-zero)
    for i in firstindex(raw)+1:lastindex(raw)
        if raw[i] != raw[i-1] && raw[i] > 0
            push!(idx, i)
            push!(val, raw[i])
            count[raw[i]] = get(count, raw[i], 0) + 1
        end
    end
    
    # Time mapping [sample_index, seconds]
    time = zeros(Float64, length(idx), 2)
    time[:, 1] .= idx
    time[:, 2] .= idx ./ fif.header.sfreq
    
    return FifTriggers(raw, idx, val, count, time)
end
