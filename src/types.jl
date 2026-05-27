"""
Data structure containing the 3D position and orientation of a channel.
"""
struct FifChPos
    loc::NTuple{3, Float32} # x, y, z location
    ex::NTuple{3, Float32}  # x-axis orientation
    ey::NTuple{3, Float32}  # y-axis orientation
    ez::NTuple{3, Float32}  # z-axis orientation
end

"""
Data structure containing information about a single FIF channel.
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
In a directory table, `next_pos` represents the absolute byte offset of the payload.
"""
struct FifTag
    kind::Int32
    type::UInt32
    size::Int32
    next_pos::Int32
end

"""
A node in the FIFF directory tree.
"""
mutable struct FifNode
    block_id::Int32
    tags::Vector{FifTag}
    children::Vector{FifNode}
    parent::Union{Nothing, FifNode}
end

"""
A Signal Space Projection (SSP) item.
"""
mutable struct FifProj
    kind::Int32
    active::Bool
    name::String
    channels::Vector{String}
    data::Matrix{Float32} # n_vecs × n_channels
end

"""
Data structure containing FIF file header information.
"""
mutable struct FifHeader
    sfreq::Float32
    nchan::Int32
    ch_info::Vector{FifChInfo}
    projs::Vector{FifProj}
end

"""
Data structure containing FIF trigger events.
"""
mutable struct FifTriggers
  raw::Vector{Int32}
  idx::Vector{Int}
  val::Vector{Int}
  count::OrderedDict{Int, Int}
  time::Matrix{Float64}
end

"""
Complete data structure containing continuous FIF raw data and metadata.
"""
mutable struct FifData
  filename::String
  header::FifHeader
  triggers::FifTriggers
  data::Matrix{Float32} # [Channels × Time]
end

"""
Complete data structure containing epoched or averaged FIF data and metadata.
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

function Base.show(io::IO, ::MIME"text/plain", fif::FifData)
    print(io, "FifData: $(size(fif.data, 2)) samples @ $(fif.header.sfreq) Hz (=$(round(size(fif.data, 2)/fif.header.sfreq, digits=2)) s), $(fif.header.nchan) channels, $(length(fif.triggers.idx)) triggers")
end

function Base.show(io::IO, ::MIME"text/plain", fif::FifEpochs)
    n_conds = size(fif.data, 3)
    cond_str = n_conds == 1 ? "1 condition" : "$n_conds conditions"
    print(io, "FifEpochs: $(size(fif.data, 2)) samples/epoch, $cond_str, $(fif.header.nchan) channels")
end
