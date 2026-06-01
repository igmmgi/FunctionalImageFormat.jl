"""
    FunctionalImageFormat

Native Julia package for reading and writing FIFF (Functional Image File Format)
files used in MEG/EEG neuroimaging.

This package provides functionality to:
- Read continuous raw `.fif` files into Julia data structures
- Read evoked/averaged `.fif` files with multiple conditions
- Write `FifData` and `FifEpochs` objects back to `.fif` format
- Extract trigger events from stimulus channels
- Preserve Signal Space Projection (SSP) information

# File Format
FIFF files use a big-endian binary tag-based format. Each tag has a 16-byte header
(kind, type, size, next_pos) followed by its payload. The format supports hierarchical
block nesting for organizing measurement info, raw data, and evoked responses.

# Quick Start
```julia
using FunctionalImageFormat

# Read continuous raw data
fif = read_fif("sample_raw.fif")

# Read evoked/averaged data
evoked = read_fif("sample-ave.fif")

# Write back to disk
write_fif("output_raw.fif", fif)
```

# License
This package is licensed under the MIT License.
"""
module FunctionalImageFormat

using OrderedCollections

# Include organized module files
include("constants.jl")
include("types.jl")
include("io.jl")
include("write.jl")
include("channels.jl")
include("processing.jl")

export
  FifData,
  FifEpochs,
  FifHeader,
  FifTriggers,
  FifChInfo,
  FifChPos,
  read_fif,
  write_fif,
  channel_index

end # module
