# FunctionalImageFormat.jl

A native Julia package for reading and writing [FIFF (Functional Image File Format)](https://mne.tools/stable/auto_tutorials/io/plot_20_reading_eeg_data.html) files used in MEG/EEG neuroimaging.


## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/igmmgi/FunctionalImageFormat.jl")
```

## Quick Start

```julia
using FunctionalImageFormat

# Read continuous raw data
fif = read_fif("sample_raw.fif")
fif.data          # Matrix{Float32} [channels × time]
fif.header.sfreq  # Sampling rate
fif.header.ch_info # Channel metadata
fif.triggers      # Extracted trigger events

# Write back to disk
write_fif("output_raw.fif", fif)

# Read evoked/averaged data
evoked = read_fif("sample-ave.fif")
evoked.data       # Array{Float32,3} [channels × time × conditions]
```

## Supported Data Types

| Format | Read | Write |
|--------|------|-------|
| Continuous raw (`FIFFB_RAW_DATA`) | ✅ | ✅ |
| Evoked/averaged (`FIFFB_EVOKED`) | ✅ | ✅ |
| SSP projectors (`FIFFB_PROJ_ITEM`) | ✅ | 🔜 |
| Channel info (96-byte structs) | ✅ | ✅ |
| Trigger extraction (STI channels) | ✅ | — |

## Performance

Optimized for fast I/O with in-place byte-swapping and minimal allocations.
Benchmarks on sample data (376 channels × 14,400 samples) show read times of ~10 ms.

## License

MIT
