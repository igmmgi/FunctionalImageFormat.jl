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

fif.data           # Matrix{Float32} [channels × time]
fif.header.sfreq   # Sampling rate
fif.header.ch_info # Channel metadata
fif.triggers       # Extracted trigger events

# Write back to disk
write_fif("output_raw.fif", fif)
```

## Acknowledgments

Development and refactoring of the core I/O architecture was assisted by Google's Gemini 3.1., with reference to the MNE-Python FIFF I/O code.

## License

MIT
