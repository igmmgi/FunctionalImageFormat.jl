using Test
using FunctionalImageFormat

@testset "FunctionalImageFormat.jl" begin
    @testset "Core I/O Tests" begin
        # To run this test, use a standard sample FIF file (e.g., from the MNE testing dataset)
        # and place it in the `test/` directory.
        
        test_file = joinpath(@__DIR__, "test_raw.fif")
        
        if isfile(test_file)
            @info "Running tests against $test_file"
            
            # 1. Read the file
            fif = read_fif(test_file)
            
            # 2. Check metadata was extracted
            @test fif.header.nchan == 376
            @test isapprox(fif.header.sfreq, 600.615, atol=0.01)
            @test length(fif.header.ch_info) == fif.header.nchan
            
            # Channel validations
            @test fif.header.ch_info[1].ch_name == "MEG 0113"
            @test fif.header.ch_info[2].ch_name == "MEG 0112"
            @test length(fif.header.ch_info[1].pos.loc) == 3
            @test fif.header.ch_info[1].unit_mul == 0 # Base unit
            
            # Projector validations
            @test length(fif.header.projs) == 3
            @test fif.header.projs[1].name == "PCA-v1"
            @test !fif.header.projs[1].active
            @test size(fif.header.projs[1].data) == (1, 102)
            @test length(fif.header.projs[1].channels) == 102
            
            # 3. Check data was loaded and reshaped correctly
            @test size(fif.data, 1) == 376
            @test size(fif.data, 2) == 14400 # 24 seconds at 600Hz
            @test typeof(fif.data) == Matrix{Float32}
            
            # 4. Check trigger extraction (if present)
            if !isempty(fif.triggers.idx)
                @test length(fif.triggers.idx) == length(fif.triggers.val)
                @test size(fif.triggers.time, 1) == length(fif.triggers.idx)
            end
            
            # 5. Check write_fif roundtrip
            out_file = joinpath(@__DIR__, "test_raw_out.fif")
            write_fif(out_file, fif)
            fif_roundtrip = read_fif(out_file)
            @test maximum(abs.(fif.data .- fif_roundtrip.data)) == 0.0
            @test fif.header.nchan == fif_roundtrip.header.nchan
            @test fif.header.sfreq == fif_roundtrip.header.sfreq
            rm(out_file)
            
            # 6. Check header_only read
            fif_header = read_fif(test_file, header_only=true)
            @test size(fif_header.data) == (376, 0)
            @test fif_header.header.nchan == 376
        else
            @warn "No $test_file found in the test/ directory. Skipping raw FIFF tests."
            @test true
        end

        test_epochs_file = joinpath(@__DIR__, "test_epochs.fif")
        if isfile(test_epochs_file)
            @info "Running tests against $test_epochs_file"
            fif_epochs = read_fif(test_epochs_file)
            
            # 1. Check it returned a FifEpochs object (or fallback for now)
            @test fif_epochs.header.nchan > 0
            
            # 2. Check the data matrix contains the extracted conditions
            @test size(fif_epochs.data, 1) == 376
            @test size(fif_epochs.data, 2) == 421 # 421 samples per condition
            @test size(fif_epochs.data, 3) == 4 # 4 conditions
            
            @test fif_epochs.comments == ["Left Auditory", "Right Auditory", "Left visual", "Right visual"]
            @test fif_epochs.nave == [3, 6, 6, 6]
            
            # Projector validations for Evoked
            @test length(fif_epochs.header.projs) == 4
            @test fif_epochs.header.projs[4].name == "Average EEG reference"
            
            # 3. Check write_fif roundtrip
            out_epochs_file = joinpath(@__DIR__, "test_epochs_out.fif")
            write_fif(out_epochs_file, fif_epochs)
            fif_epochs_roundtrip = read_fif(out_epochs_file)
            @test maximum(abs.(fif_epochs.data .- fif_epochs_roundtrip.data)) == 0.0
            @test fif_epochs.header.nchan == fif_epochs_roundtrip.header.nchan
            @test fif_epochs.header.sfreq == fif_epochs_roundtrip.header.sfreq
            rm(out_epochs_file)
        else
            @warn "No $test_epochs_file found. Skipping Evoked tests."
        end
    end

    @testset "Utility Functions" begin
        labels = ["EEG 001", "EEG 002", "STI 014", "MEG 0113"]
        
        # Test string lookup
        @test channel_index(labels, ["EEG 002", "STI 014"]) == [2, 3]
        @test channel_index(labels, "MEG 0113") == [4]
        
        # Test integer passthrough bounds
        @test channel_index(labels, [1, 4]) == [1, 4]
        @test channel_index(labels, 2) == [2]
        
        # Test error handling
        @test_throws ErrorException channel_index(labels, "NOT_FOUND")
        @test_throws ErrorException channel_index(labels, [0, 1])
        @test_throws ErrorException channel_index(labels, 5)
    end
end
