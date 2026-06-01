"""
    FifChPos

Data structure containing the 3D position and orientation of a channel.

# Fields
- `loc::NTuple{3, Float32}`: x, y, z location in meters
- `ex::NTuple{3, Float32}`: x-axis unit orientation vector
- `ey::NTuple{3, Float32}`: y-axis unit orientation vector
- `ez::NTuple{3, Float32}`: z-axis unit orientation vector
"""
struct FifChPos
    loc::NTuple{3, Float32} # x, y, z location
    ex::NTuple{3, Float32}  # x-axis orientation
    ey::NTuple{3, Float32}  # y-axis orientation
    ez::NTuple{3, Float32}  # z-axis orientation
end

"""
    FifChInfo

Data structure containing information about a single FIF channel.

# Fields
- `scan_no::Int32`: Scanning order number
- `log_no::Int32`: Logical channel number
- `kind::Int32`: Channel type (1=MEG, 2=EEG, 3=STIM, 301=EOG, 302=EMG)
- `range::Float32`: Hardware range scaling factor
- `cal::Float32`: Calibration factor (from raw units to physical units)
- `coil_type::Int32`: Coil/electrode type identifier
- `pos::FifChPos`: 3D position and orientation
- `unit::Int32`: Physical unit (e.g., 112=V, 201=T)
- `unit_mul::Int32`: Unit multiplier exponent (e.g., -6 for µV)
- `ch_name::String`: Channel name (max 16 characters)

# Notes
- Physical value = raw_value × range × cal
- Channel kind `3` indicates a stimulus/trigger channel
"""
struct FifChInfo
    scan_no::Int32
    log_no::Int32
    kind::Int32
    range::Float32
    cal::Float32
    coil_type::Int32
    pos::FifChPos
    unit::Int32
    unit_mul::Int32
    ch_name::String
end

"""
    FifTag

Internal struct representing a 16-byte FIFF tag header or directory entry.

# Fields
- `kind::Int32`: Tag identifier (e.g., FIFF_SFREQ, FIFF_CH_INFO)
- `type::UInt32`: Data type of the payload
- `size::Int32`: Payload size in bytes
- `next_pos::Int32`: In directory entries, the absolute byte offset of the payload
"""
struct FifTag
    kind::Int32
    type::UInt32
    size::Int32
    next_pos::Int32
end

"""
    FifNode

A node in the FIFF directory tree, representing a block (e.g., measurement info,
raw data, evoked data) and its contained tags and child blocks.

# Fields
- `block_id::Int32`: Block type identifier (e.g., FIFFB_MEAS_INFO, FIFFB_RAW_DATA)
- `tags::Vector{FifTag}`: Tags directly contained in this block
- `children::Vector{FifNode}`: Child blocks
- `parent::Union{Nothing, FifNode}`: Parent block (nothing for root)
"""
mutable struct FifNode
    block_id::Int32
    tags::Vector{FifTag}
    children::Vector{FifNode}
    parent::Union{Nothing, FifNode}
end

"""
    FifProj

A Signal Space Projection (SSP) item used for noise reduction.

# Fields
- `kind::Int32`: Projection type identifier
- `active::Bool`: Whether this projector is currently active
- `name::String`: Descriptive name (e.g., "PCA-v1")
- `channels::Vector{String}`: Channel names this projector applies to
- `data::Matrix{Float32}`: Projection vectors (n_vecs × n_channels)
"""
mutable struct FifProj
    kind::Int32
    active::Bool
    name::String
    channels::Vector{String}
    data::Matrix{Float32} # n_vecs × n_channels
end

"""
    FifHeader

Data structure containing FIF file header information.

# Fields
- `sfreq::Float32`: Sampling frequency in Hz
- `nchan::Int32`: Number of channels
- `ch_info::Vector{FifChInfo}`: Channel metadata for each channel
- `projs::Vector{FifProj}`: Signal Space Projection items
"""
mutable struct FifHeader
    sfreq::Float32
    nchan::Int32
    ch_info::Vector{FifChInfo}
    projs::Vector{FifProj}
end

"""
    FifTriggers

Data structure containing FIF trigger events extracted from stimulus channels.

# Fields
- `raw::Vector{Int32}`: Raw trigger values for every sample (0 for no trigger)
- `idx::Vector{Int}`: Sample indices where trigger rising edges occur
- `val::Vector{Int}`: Trigger values at each rising edge
- `count::OrderedDict{Int, Int}`: Count of each unique trigger value
- `time::Matrix{Float64}`: Timing matrix (N × 2): column 1 = sample index, column 2 = time in seconds
"""
mutable struct FifTriggers
  raw::Vector{Int32}
  idx::Vector{Int}
  val::Vector{Int}
  count::OrderedDict{Int, Int}
  time::Matrix{Float64}
end

"""
    FifData

Complete data structure containing continuous FIF raw data and metadata.

# Fields
- `filename::String`: Source filename
- `header::FifHeader`: File header with channel info and sampling rate
- `triggers::FifTriggers`: Extracted trigger events from stimulus channels
- `data::Matrix{Float32}`: EEG/MEG data matrix [channels × time]

# Notes
- Data layout is channels × time (row-major for channel access)
- Data values are in physical units (calibration already applied)
"""
mutable struct FifData
  filename::String
  header::FifHeader
  triggers::FifTriggers
  data::Matrix{Float32} # [Channels × Time]
end

"""
    FifEpochs

Complete data structure containing epoched or averaged FIF data and metadata.

# Fields
- `filename::String`: Source filename
- `header::FifHeader`: File header with channel info and sampling rate
- `data::Array{Float32, 3}`: Data array [channels × time × epochs/conditions]
- `comments::Vector{String}`: Condition labels (e.g., "Left Auditory")
- `nave::Vector{Int32}`: Number of averages per condition
- `first_sample::Vector{Int32}`: First sample index per condition
- `last_sample::Vector{Int32}`: Last sample index per condition

# Notes
- For evoked files, each "epoch" is an averaged condition
- `nave` indicates how many trials were averaged to produce each condition
"""
mutable struct FifEpochs
  filename::String
  header::FifHeader
  data::Array{Float32, 3} # [Channels × Time × Epochs]
  comments::Vector{String}
  nave::Vector{Int32}
  first_sample::Vector{Int32}
  last_sample::Vector{Int32}
end

# Pretty Printing
function Base.show(io::IO, header::FifHeader)
    print(io, "FifHeader($(header.nchan) channels, $(header.sfreq) Hz, $(length(header.projs)) projectors)")
end

function Base.show(io::IO, ::MIME"text/plain", header::FifHeader)
    println(io, "FifHeader:")
    println(io, "  Channels: $(header.nchan)")
    println(io, "  Sample Rate: $(header.sfreq) Hz")
    print(io, "  Projectors: $(length(header.projs))")
end

function Base.show(io::IO, fif::FifData)
    print(io, "FifData($(size(fif.data, 2)) samples, $(fif.header.nchan) channels, $(length(fif.triggers.idx)) triggers)")
end

function Base.show(io::IO, ::MIME"text/plain", fif::FifData)
    print(io, "FifData: $(size(fif.data, 2)) samples @ $(fif.header.sfreq) Hz (=$(round(size(fif.data, 2)/fif.header.sfreq, digits=2)) s), $(fif.header.nchan) channels, $(length(fif.triggers.idx)) triggers")
end

function Base.show(io::IO, fif::FifEpochs)
    n_conds = size(fif.data, 3)
    cond_str = n_conds == 1 ? "1 condition" : "$n_conds conditions"
    print(io, "FifEpochs($cond_str, $(size(fif.data, 2)) samples, $(fif.header.nchan) channels)")
end

function Base.show(io::IO, ::MIME"text/plain", fif::FifEpochs)
    n_conds = size(fif.data, 3)
    cond_str = n_conds == 1 ? "1 condition" : "$n_conds conditions"
    print(io, "FifEpochs: $(size(fif.data, 2)) samples/epoch, $cond_str, $(fif.header.nchan) channels")
end
