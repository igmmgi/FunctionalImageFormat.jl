# io.jl — FIFF file reading
"""
    read_tag(io)

Read the next 16-byte FIFF tag from the file stream.
FIFF files are Big-Endian, so we must `ntoh` the bytes.
"""
function read_tag(io::IO)
    kind = ntoh(read(io, Int32))
    type = ntoh(read(io, UInt32))
    size = ntoh(read(io, Int32))
    next_pos = ntoh(read(io, Int32))
    return FifTag(kind, type, size, next_pos)
end

"""
    read_ch_info(io)

Read a 96-byte FIFF_CH_INFO struct from the stream.
"""
function read_ch_info(io::IO)
    scan_no = ntoh(read(io, Int32))
    log_no = ntoh(read(io, Int32))
    kind = ntoh(read(io, Int32))
    range = ntoh(read(io, Float32))
    cal = ntoh(read(io, Float32))
    coil = ntoh(read(io, Int32))

    # Extract 3D Coordinates (48 bytes: 12 floats)
    read_vec3() = (ntoh(read(io, Float32)), ntoh(read(io, Float32)), ntoh(read(io, Float32)))
    pos = FifChPos(read_vec3(), read_vec3(), read_vec3(), read_vec3())

    unit = ntoh(read(io, Int32))
    unit_mul = ntoh(read(io, Int32))

    # Channel name is fixed 16 bytes, null-padded
    name_bytes = read(io, 16)
    null_idx = findfirst(isequal(0x00), name_bytes)
    end_idx = null_idx === nothing ? 16 : null_idx - 1
    ch_name = String(name_bytes[1:end_idx])

    return FifChInfo(scan_no, log_no, kind, range, cal, coil, pos, unit, unit_mul, ch_name)
end

"""
    read_proj(io, node)

Read a single SSP Projector from a FIFFB_PROJ_ITEM node.
"""
function read_proj(io::IO, node::FifNode)
    kind = Int32(0)
    active = false
    name = ""
    channels = String[]
    data = Matrix{Float32}(undef, 0, 0)

    for tag in node.tags
        seek(io, tag.next_pos + 16)
        if tag.kind == FIFF_PROJ_ITEM_KIND
            kind = ntoh(read(io, Int32))
        elseif tag.kind == FIFF_MNE_PROJ_ITEM_ACTIVE
            active = ntoh(read(io, Int32)) != 0
        elseif tag.kind == FIFF_NAME
            name = String(read(io, tag.size))
        elseif tag.kind == FIFF_PROJ_ITEM_CH_NAME_LIST
            channels = split(String(read(io, tag.size)), ":")
        elseif tag.kind == FIFF_PROJ_ITEM_VECTORS
            # Matrix reading logic
            is_matrix = (tag.type & 0x40000000) != 0
            if is_matrix
                seek(io, tag.next_pos + 16 + tag.size - 4)
                ndim = ntoh(read(io, Int32))
                seek(io, tag.next_pos + 16 + tag.size - 4 - (4 * ndim))
                dims = [ntoh(read(io, Int32)) for _ in 1:ndim]
                reverse!(dims) # (n_vecs, n_channels)

                seek(io, tag.next_pos + 16)
                data_bytes = tag.size - 4 - (4 * length(dims))
                n_vals = data_bytes ÷ 4
                buf = read!(io, Vector{Float32}(undef, n_vals))
                buf .= ntoh.(buf)
                data = reshape(buf, Tuple(dims))
            end
        end
    end

    return FifProj(kind, active, name, channels, data)
end

"""
    read_dir_tree(io)

Parse the FIFF directory index to build a hierarchical tree of nodes in memory.
"""
function read_dir_tree(io::IO)
    seekstart(io)
    first_tag = read_tag(io)
    if first_tag.kind != FIFF_FILE_ID
        error("Invalid FIF file: Missing FIFF_FILE_ID at file start.")
    end

    # Look for FIFF_DIR_POINTER right after FILE_ID payload
    seek(io, position(io) + first_tag.size)
    second_tag = read_tag(io)
    dir_pos = 0
    if second_tag.kind == FIFF_DIR_POINTER
        dir_pos = ntoh(read(io, Int32))
    end

    dir_entries = FifTag[]

    if dir_pos > 0
        seek(io, dir_pos)
        dir_tag = read_tag(io)
        if dir_tag.kind == FIFF_DIR
            n_entries = dir_tag.size ÷ 16
            for _ in 1:n_entries
                kind = ntoh(read(io, Int32))
                type = ntoh(read(io, UInt32))
                size = ntoh(read(io, Int32))
                pos = ntoh(read(io, Int32))
                push!(dir_entries, FifTag(kind, type, size, pos))
            end
        end
    end

    if isempty(dir_entries)
        # Fallback: sequential scan for files missing a directory index
        seekstart(io)
        tag1 = read_tag(io)
        seek(io, position(io) + tag1.size)
        while !eof(io)
            pos_before = position(io)
            tag = read_tag(io)
            push!(dir_entries, FifTag(tag.kind, tag.type, tag.size, pos_before))
            seek(io, pos_before + 16 + tag.size)
        end
    end

    # Assemble hierarchical tree
    root = FifNode(0, FifTag[], FifNode[], nothing)
    current = root

    for entry in dir_entries
        if entry.kind == FIFF_BLOCK_START
            # entry.next_pos points to the start of the tag in the directory
            seek(io, entry.next_pos + 16)
            block_id = ntoh(read(io, Int32))
            child = FifNode(block_id, FifTag[], FifNode[], current)
            push!(current.children, child)
            current = child
        elseif entry.kind == FIFF_BLOCK_END
            if current.parent !== nothing
                current = current.parent
            end
        else
            push!(current.tags, entry)
        end
    end

    return root
end

"""
    find_nodes(node, target_block)

Recursively find all nodes with a matching block ID.
"""
function find_nodes(node::FifNode, target_block::Int32)
    found = FifNode[]
    if node.block_id == target_block
        push!(found, node)
    end
    for child in node.children
        append!(found, find_nodes(child, target_block))
    end
    return found
end

"""
    extract_all_tags!(node, tags_out)

Recursively extract all tags from a node and its children.
"""
function extract_all_tags!(node::FifNode, tags_out::Vector{FifTag})
    append!(tags_out, node.tags)
    for child in node.children
        extract_all_tags!(child, tags_out)
    end
end

"""
    read_fif(filename; header_only=false, channels=[])

Read FIF data structure from a `.fif` file.
"""
function read_fif(filename::AbstractString; header_only::Bool=false, verbose::Bool=true)
    if verbose
        @info "Reading file: $filename"
    end
    if !isfile(filename)
        error("File does not exist: $filename")
    end

    header_sfreq = 0.0f0
    header_nchan = Int32(0)
    ch_infos = FifChInfo[]
    projs = FifProj[]
    data_buffers = Vector{Float32}[]
    is_epochs = false

    io = open(filename, "r")
    try

        # 1. Build the FIFF directory tree
        tree = read_dir_tree(io)

        # 2. Extract Measurement Info
        meas_nodes = find_nodes(tree, Int32(FIFFB_MEAS_INFO))
        if isempty(meas_nodes)
            error("No FIFF_BLOCK_MEAS_INFO found in the file.")
        end
        meas_info = meas_nodes[1]

        for tag in meas_info.tags
            if tag.kind == FIFF_SFREQ
                seek(io, tag.next_pos + 16)
                header_sfreq = ntoh(read(io, Float32))
            elseif tag.kind == FIFF_NCHAN
                seek(io, tag.next_pos + 16)
                header_nchan = ntoh(read(io, Int32))
            elseif tag.kind == FIFF_CH_INFO
                seek(io, tag.next_pos + 16)
                push!(ch_infos, read_ch_info(io))
            end
        end

        # 2.5 Extract Projectors
        proj_nodes = find_nodes(meas_info, Int32(FIFFB_PROJ_ITEM))
        for pnode in proj_nodes
            push!(projs, read_proj(io, pnode))
        end

        header = FifHeader(header_sfreq, header_nchan, ch_infos, projs)
        if verbose
            @info "Successfully parsed header: $(header.nchan) channels, $(length(projs)) projectors at $(header.sfreq) Hz"
        end

        if header_only
            return FifData(filename, header, FifTriggers(Int32[], Int[], Int[], OrderedDict{Int,Int}(), Matrix{Float64}(undef, 0, 2)), Matrix{Float32}(undef, header.nchan, 0))
        end

        # 3. Extract Data Blocks
        raw_nodes = find_nodes(tree, Int32(FIFFB_RAW_DATA))
        evoked_nodes = find_nodes(tree, Int32(FIFFB_EVOKED))
        mne_epochs_nodes = find_nodes(tree, Int32(373)) # FIFFB_MNE_EPOCHS

        target_nodes = raw_nodes
        is_epochs = false
        is_mne_epochs = false

        if !isempty(mne_epochs_nodes)
            target_nodes = mne_epochs_nodes
            is_epochs = true
            is_mne_epochs = true
        elseif !isempty(evoked_nodes)
            target_nodes = evoked_nodes
            is_epochs = true
        end

        ev_comments = String[]
        ev_nave = Int32[]
        ev_first = Int32[]
        ev_last = Int32[]

        mne_epochs_dims = Int32[]

        for node in target_nodes
            # In evoked files, data buffers are inside sub-blocks (Aspects), so we flatten all child tags
            all_tags = FifTag[]
            extract_all_tags!(node, all_tags)

            comment = ""
            nave = Int32(1)
            first = Int32(0)
            last = Int32(0)

            for tag in all_tags
                if tag.kind == FIFF_COMMENT
                    seek(io, tag.next_pos + 16)
                    comment = String(read(io, tag.size))
                elseif tag.kind == FIFF_NAVE
                    seek(io, tag.next_pos + 16)
                    nave = ntoh(read(io, Int32))
                elseif tag.kind == FIFF_FIRST_SAMPLE
                    seek(io, tag.next_pos + 16)
                    first = ntoh(read(io, Int32))
                elseif tag.kind == FIFF_LAST_SAMPLE
                    seek(io, tag.next_pos + 16)
                    last = ntoh(read(io, Int32))
                elseif tag.kind == FIFF_DATA_BUFFER || tag.kind == FIFF_EPOCH
                    seek(io, tag.next_pos + 16)

                    # Check for FIFFT_MATRIX bit (0x40000000)
                    is_matrix = (tag.type & 0x40000000) != 0
                    dims = Int32[]
                    if is_matrix
                        # FIFF stores matrix dimensions at the VERY END of the payload
                        seek(io, tag.next_pos + 16 + tag.size - 4)
                        ndim = ntoh(read(io, Int32))

                        seek(io, tag.next_pos + 16 + tag.size - 4 - (4 * ndim))
                        dims = [ntoh(read(io, Int32)) for _ in 1:ndim]
                        reverse!(dims) # MNE reverses dims

                        if is_mne_epochs && ndim == 3
                            mne_epochs_dims = dims
                        end

                        # Seek back to start of payload for actual data
                        seek(io, tag.next_pos + 16)
                    end

                    dtype = tag.type & 0x00000FFF

                    # Calculate how many bytes are left for data
                    data_bytes = is_matrix ? tag.size - 4 - (4 * length(dims)) : tag.size

                    if dtype == 4
                        n_vals = data_bytes ÷ 4
                        buf = Vector{Float32}(undef, n_vals)
                        read!(io, buf)
                        buf .= ntoh.(buf)
                        push!(data_buffers, buf)
                    elseif dtype == 2 || dtype == 16
                        n_vals = data_bytes ÷ 2
                        buf = read!(io, Vector{Int16}(undef, n_vals))
                        push!(data_buffers, Float32.(ntoh.(buf)))
                    elseif dtype == 3
                        n_vals = data_bytes ÷ 4
                        buf = read!(io, Vector{Int32}(undef, n_vals))
                        push!(data_buffers, Float32.(ntoh.(buf)))
                    else
                        @warn "Unsupported data buffer type $dtype, skipping."
                    end
                end
            end

            if is_epochs
                push!(ev_comments, comment)
                push!(ev_nave, nave)
                push!(ev_first, first)
                push!(ev_last, last)
            end
        end

        # Assemble Data Matrix
        if !isempty(data_buffers)
            total_vals = sum(length, data_buffers)
            raw_vec = reduce(vcat, data_buffers)

            # Precompute calibration scales once for all channels
            scales = [info.range * info.cal for info in header.ch_info]

            if is_mne_epochs && length(mne_epochs_dims) == 3
                n_epochs, n_chan, n_time = mne_epochs_dims[1], mne_epochs_dims[2], mne_epochs_dims[3]

                # MNE stores epochs as [Time, Channels, Epochs] in flat memory
                reshaped = reshape(raw_vec, (n_time, n_chan, n_epochs))
                data_matrix = permutedims(reshaped, (2, 1, 3))
                data_matrix .*= scales

                if verbose
                    @info "Returning FifEpochs with $n_epochs epochs"
                end
                return FifEpochs(filename, header, data_matrix, ev_comments, ev_nave, ev_first, ev_last)

            elseif is_epochs
                n_conditions = length(target_nodes)
                n_cols_per_cond = (total_vals ÷ header.nchan) ÷ n_conditions

                # Reshape directly into 3D: [Channels × Time × Conditions]
                data_matrix = reshape(raw_vec, (Int(header.nchan), n_cols_per_cond, n_conditions))
                data_matrix .*= scales

                if verbose
                    @info "Returning FifEpochs with $n_conditions conditions"
                end
                return FifEpochs(filename, header, data_matrix, ev_comments, ev_nave, ev_first, ev_last)
            else
                # Standard Raw Data 2D reshape
                n_cols = total_vals ÷ header.nchan
                data_matrix = reshape(raw_vec, (Int(header.nchan), n_cols))
                data_matrix .*= scales

                if verbose
                    @info "Assembled raw data matrix: $(size(data_matrix))"
                end

                fif_out = FifData(filename, header, FifTriggers(Int32[], Int[], Int[], OrderedDict{Int,Int}(), Matrix{Float64}(undef, 0, 2)), data_matrix)
                fif_out.triggers = trigger_info(fif_out, verbose=verbose)
                return fif_out
            end
        else
            if is_epochs
                return FifEpochs(filename, header, Array{Float32,3}(undef, header.nchan, 0, 0), String[], Int32[], Int32[], Int32[])
            else
                return FifData(filename, header, FifTriggers(Int32[], Int[], Int[], OrderedDict{Int,Int}(), Matrix{Float64}(undef, 0, 2)), Matrix{Float32}(undef, header.nchan, 0))
            end
        end

    finally
        close(io)
    end
end
