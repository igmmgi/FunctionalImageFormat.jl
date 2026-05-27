# write.jl — FIFF file writing
function write_tag_header(io::IO, dir::Vector{FifTag}, kind::Integer, type::UInt32, size::Int32)
    pos = Int32(position(io))
    write(io, hton(Int32(kind)))
    write(io, hton(type))
    write(io, hton(size))
    write(io, hton(Int32(0))) # next_pos = 0
    push!(dir, FifTag(Int32(kind), type, size, pos))
    return pos
end

function write_int_tag(io::IO, dir::Vector{FifTag}, kind::Integer, val::Int32)
    write_tag_header(io, dir, kind, FIFFT_INT, Int32(4))
    write(io, hton(val))
end

function write_float_tag(io::IO, dir::Vector{FifTag}, kind::Integer, val::Float32)
    write_tag_header(io, dir, kind, FIFFT_FLOAT, Int32(4))
    write(io, hton(val))
end

function write_string_tag(io::IO, dir::Vector{FifTag}, kind::Integer, val::String)
    bytes = Vector{UInt8}(val)
    write_tag_header(io, dir, kind, FIFFT_STRING, Int32(length(bytes)))
    write(io, bytes)
end

function write_float_matrix_tag(io::IO, dir::Vector{FifTag}, kind::Integer, mat::AbstractArray{Float32})
    # MNE restricts FIFF_EPOCH to 2D matrices, so we flatten 3D into 2D if necessary
    n_rows = size(mat, 1)
    n_cols = div(length(mat), n_rows)
    dims = Int32[n_cols, n_rows]
    ndim = Int32(2)

    mat_bytes = length(mat) * 4
    dim_bytes = 4 * 2
    ndim_bytes = 4

    payload_size = mat_bytes + dim_bytes + ndim_bytes
    type = FIFFT_FLOAT | 0x40000000

    write_tag_header(io, dir, kind, type, Int32(payload_size))

    for val in mat
        write(io, hton(Float32(val)))
    end

    for d in dims
        write(io, hton(d))
    end

    write(io, hton(ndim))
end

function write_block_start(io::IO, dir::Vector{FifTag}, block_id::Integer)
    write_int_tag(io, dir, FIFF_BLOCK_START, Int32(block_id))
end

function write_block_end(io::IO, dir::Vector{FifTag}, block_id::Integer)
    write_int_tag(io, dir, FIFF_BLOCK_END, Int32(block_id))
end

function write_proj(io::IO, dir::Vector{FifTag}, projs::Vector{FifProj})
    if isempty(projs)
        return
    end

    write_block_start(io, dir, FIFFB_PROJ)
    for proj in projs
        write_block_start(io, dir, FIFFB_PROJ_ITEM)

        write_int_tag(io, dir, FIFF_NAME, Int32(0)) # MNE sometimes puts an ID struct, but we just need the tags
        write_string_tag(io, dir, FIFF_NAME, proj.name)
        write_int_tag(io, dir, FIFF_PROJ_ITEM_KIND, proj.kind)
        write_int_tag(io, dir, FIFF_MNE_PROJ_ITEM_ACTIVE, Int32(proj.active ? 1 : 0))
        write_string_tag(io, dir, FIFF_PROJ_ITEM_CH_NAME_LIST, join(proj.channels, ":"))

        # MNE writes vectors as a FIFF_PROJ_ITEM_VECTORS matrix
        # write_float_matrix_tag always writes a 2D matrix
        write_float_matrix_tag(io, dir, FIFF_PROJ_ITEM_VECTORS, proj.data)

        write_int_tag(io, dir, FIFF_PROJ_ITEM_NVEC, Int32(size(proj.data, 1)))

        write_block_end(io, dir, FIFFB_PROJ_ITEM)
    end
    write_block_end(io, dir, FIFFB_PROJ)
end

function write_id_struct(io::IO, dir::Vector{FifTag}, kind::Integer)
    write_tag_header(io, dir, kind, FIFFT_ID_STRUCT, Int32(20))
    write(io, hton(Int32(1))) # version
    write(io, hton(Int32(0))) # machid[0]
    write(io, hton(Int32(0))) # machid[1]
    write(io, hton(Int32(round(Int, time())))) # secs
    write(io, hton(Int32(0))) # usecs
end

function write_ch_info_tag(io::IO, dir::Vector{FifTag}, ch::FifChInfo)
    write_tag_header(io, dir, FIFF_CH_INFO, FIFFT_CH_INFO_STRUCT, Int32(96))
    write(io, hton(ch.scan_no))
    write(io, hton(ch.log_no))
    write(io, hton(ch.kind))
    write(io, hton(Float32(1.0))) # range (forced to 1.0 since data is pre-scaled)
    write(io, hton(Float32(1.0))) # cal (forced to 1.0)
    write(io, hton(ch.coil_type))
    # loc is 12 Float32s (48 bytes)
    for i in 1:3
        write(io, hton(Float32(ch.pos.loc[i])))
    end
    for i in 1:3
        write(io, hton(Float32(ch.pos.ex[i])))
    end
    for i in 1:3
        write(io, hton(Float32(ch.pos.ey[i])))
    end
    for i in 1:3
        write(io, hton(Float32(ch.pos.ez[i])))
    end
    write(io, hton(ch.unit))
    write(io, hton(ch.unit_mul))
    # ch_name is 16 bytes
    name_bytes = Vector{UInt8}(ch.ch_name)
    padded_name = zeros(UInt8, 16)
    padded_name[1:min(16, length(name_bytes))] = name_bytes[1:min(16, length(name_bytes))]
    write(io, padded_name)
end

function write_dir_index(io::IO, dir::Vector{FifTag})
    # Do NOT pass `dir` to write_tag_header, because we don't want the directory tag itself 
    # appended to the directory list right as we are writing the payload!
    payload_size = Int32(16 * length(dir))
    write_tag_header(io, FifTag[], 102, FIFFT_DIR_ENTRY_STRUCT, payload_size)

    for tag in dir
        write(io, hton(tag.kind))
        write(io, hton(tag.type))
        write(io, hton(tag.size))
        write(io, hton(tag.next_pos)) # pos is stored here
    end
end

function _write_meas_info(io::IO, dir::Vector{FifTag}, header::FifHeader)
    write_id_struct(io, dir, FIFFB_MEAS_INFO)
    write_block_start(io, dir, FIFFB_MEAS_INFO)
    write_float_tag(io, dir, FIFF_SFREQ, Float32(header.sfreq))
    write_int_tag(io, dir, FIFF_NCHAN, Int32(header.nchan))

    for ch in header.ch_info
        write_ch_info_tag(io, dir, ch)
    end
    write_proj(io, dir, header.projs)
    write_block_end(io, dir, FIFFB_MEAS_INFO)
end

function _write_data_payload(io::IO, dir::Vector{FifTag}, fif::FifData)
    write_block_start(io, dir, FIFFB_RAW_DATA)

    # Chunk the data in 1000 sample blocks
    chunk_size = 1000
    n_samples = size(fif.data, 2)

    for start_idx in 1:chunk_size:n_samples
        end_idx = min(start_idx + chunk_size - 1, n_samples)
        chunk = fif.data[:, start_idx:end_idx]
        flat_chunk = vec(chunk)

        write_tag_header(io, dir, FIFF_DATA_BUFFER, FIFFT_FLOAT, Int32(length(flat_chunk) * 4))
        for val in flat_chunk
            write(io, hton(Float32(val)))
        end
    end

    write_block_end(io, dir, FIFFB_RAW_DATA)
end

function _write_data_payload(io::IO, dir::Vector{FifTag}, fif::FifEpochs)
    write_block_start(io, dir, FIFFB_PROCESSED_DATA)

    n_conds = size(fif.data, 3)
    n_samples = size(fif.data, 2)

    for i in 1:n_conds
        write_block_start(io, dir, FIFFB_EVOKED)

        comment = !isempty(fif.comments) && length(fif.comments) >= i ? fif.comments[i] : "Condition $i"
        nave = !isempty(fif.nave) && length(fif.nave) >= i ? fif.nave[i] : Int32(1)
        first_samp = !isempty(fif.first_sample) && length(fif.first_sample) >= i ? fif.first_sample[i] : Int32(0)
        last_samp = !isempty(fif.last_sample) && length(fif.last_sample) >= i ? fif.last_sample[i] : Int32(n_samples - 1)

        write_string_tag(io, dir, FIFF_COMMENT, comment)

        first_time = Float32(first_samp / fif.header.sfreq)
        write_float_tag(io, dir, FIFF_FIRST_TIME, first_time)

        write_int_tag(io, dir, FIFF_NO_SAMPLES, Int32(n_samples))
        write_int_tag(io, dir, FIFF_FIRST_SAMPLE, first_samp)
        write_int_tag(io, dir, FIFF_LAST_SAMPLE, last_samp)

        # Aspect Block
        write_block_start(io, dir, FIFFB_ASPECT)

        write_int_tag(io, dir, FIFF_ASPECT_KIND, FIFFV_ASPECT_AVERAGE)
        write_int_tag(io, dir, FIFF_NAVE, nave)

        # Write the 2D data matrix for this condition
        cond_data = fif.data[:, :, i]
        write_float_matrix_tag(io, dir, FIFF_EPOCH, cond_data)

        write_block_end(io, dir, FIFFB_ASPECT)
        write_block_end(io, dir, FIFFB_EVOKED)
    end

    write_block_end(io, dir, FIFFB_PROCESSED_DATA)
end

"""
    write_fif(filename, data::Union{FifData, FifEpochs})

Write a `FifData` or `FifEpochs` object to a `.fif` file.
"""
function write_fif(filename::AbstractString, fif::Union{FifData, FifEpochs})
    io = open(filename, "w")
    dir = FifTag[]
    try
        write_id_struct(io, dir, FIFF_FILE_ID)

        dir_ptr_pos = Int32(position(io))
        write_int_tag(io, dir, FIFF_DIR_POINTER, Int32(-1))
        write_int_tag(io, dir, FIFF_FREE_LIST, Int32(-1))

        write_block_start(io, dir, FIFFB_MEAS)
        
        _write_meas_info(io, dir, fif.header)
        _write_data_payload(io, dir, fif)
        
        write_block_end(io, dir, FIFFB_MEAS)

        dir_byte_pos = Int32(position(io))
        write_dir_index(io, dir)

        # Update dir pointer
        seek(io, dir_ptr_pos + 16)
        write(io, hton(dir_byte_pos))

    finally
        close(io)
    end
    @info "Successfully wrote $(typeof(fif)) to $filename"
end
