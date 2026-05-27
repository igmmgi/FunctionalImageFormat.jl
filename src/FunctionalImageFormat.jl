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
