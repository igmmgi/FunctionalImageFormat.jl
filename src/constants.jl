# FIFF Constants
# Reference: MNE-Python _fiff/constants.py

# ── Tag IDs ──
const FIFF_FILE_ID                = Int32(100)
const FIFF_DIR_POINTER            = Int32(101)
const FIFF_DIR                    = Int32(102)
const FIFF_BLOCK_START            = Int32(104)
const FIFF_BLOCK_END              = Int32(105)

const FIFF_NCHAN                  = Int32(200)
const FIFF_SFREQ                  = Int32(201)
const FIFF_CH_INFO                = Int32(203)
const FIFF_FIRST_TIME             = Int32(204)
const FIFF_NAVE                   = Int32(207)
const FIFF_FIRST_SAMPLE           = Int32(208)
const FIFF_LAST_SAMPLE            = Int32(209)
const FIFF_ASPECT_KIND            = Int32(210)
const FIFF_NO_SAMPLES             = Int32(201)
const FIFF_CH_NAME                = Int32(212)
const FIFF_NAME                   = Int32(233)
const FIFF_COMMENT                = Int32(206)
const FIFF_DATA_BUFFER            = Int32(300)
const FIFF_EPOCH                  = Int32(302)

# Projector tag IDs
const FIFF_PROJ_ITEM_KIND         = Int32(3411)
const FIFF_PROJ_ITEM_TIME         = Int32(3412)
const FIFF_PROJ_ITEM_NVEC         = Int32(3414)
const FIFF_PROJ_ITEM_VECTORS      = Int32(3415)
const FIFF_PROJ_ITEM_CH_NAME_LIST = Int32(3417)
const FIFF_MNE_PROJ_ITEM_ACTIVE   = Int32(3560)

# ── Block IDs ──
const FIFFB_MEAS                  = Int32(100)
const FIFFB_MEAS_INFO             = Int32(101)
const FIFFB_RAW_DATA              = Int32(102)
const FIFFB_PROCESSED_DATA        = Int32(103)
const FIFFB_EVOKED                = Int32(104)
const FIFFB_ASPECT                = Int32(105)
const FIFFB_PROJ                  = Int32(313)
const FIFFB_PROJ_ITEM             = Int32(314)

# ── Type IDs ──
const FIFFT_VOID                  = UInt32(0)
const FIFFT_INT                   = UInt32(3)
const FIFFT_FLOAT                 = UInt32(4)
const FIFFT_STRING                = UInt32(10)
const FIFFT_CH_INFO_STRUCT        = UInt32(30)
const FIFFT_ID_STRUCT             = UInt32(31)
const FIFFT_DIR_ENTRY_STRUCT      = UInt32(32)
const FIFFT_MATRIX_BIT            = UInt32(0x40000000)

# ── Misc IDs ──
const FIFF_FREE_LIST              = Int32(106)
const FIFFV_ASPECT_AVERAGE        = Int32(100)
