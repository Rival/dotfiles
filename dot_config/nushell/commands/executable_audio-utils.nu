export def "list audio-files" [directory: path = "."] {
    glob $"($directory)/**/*.{ogg,wav,mp3}"
}

# Get the sample rate of an audio file in Hz
def get-sample-rate [file: string] {
    try {
        let raw_rate = (
            ffprobe -v quiet -select_streams a:0 -show_entries stream=sample_rate -of csv=p=0 $file
            | str trim
        )
        # print $"($file) sample_rate:($raw_rate)"
        if ($raw_rate | str length) == 0 {
            return null
        }
        let intValue = ($raw_rate | into int)
            return ($intValue)
        # print $"($file) sample_rate:($intValue)"
        # if ($intValue | complete).error {
        #     return null
        # } else {
        #     return ($intValue)
        # }
    } catch {
        return null
    }
}

# Helper function to perform comparison
def compare-rates [rate: int, target: int, operator: string] {
    if $operator == "==" {
        $rate == $target
    } else if $operator == ">" {
        $rate > $target
    } else if $operator == "<" {
        $rate < $target
    } else if $operator == ">=" {
        $rate >= $target
    } else if $operator == "<=" {
        $rate <= $target
    } else {
        false
    }
}

export def "with sample-rate" []: [list -> table] {
    let audio_files = ($in | to filenames)
    $audio_files | par-each { |file|
        let rate = get-sample-rate $file
        { name: $file, sample_rate: $rate }
    }
}

export def "only audio sample-rate" [
    target_samplerate: int,      # Target sample rate in Hz (e.g., 44100)
    operator: string = "=="      # Comparison: ==, >, <, >=, <=
]: [
    list -> list
] {
    # let audio_files = $in
    let audio_files = ($in | to filenames)
    if (which ffprobe | is-empty) {
        error make { msg: "ffprobe is required but not found in PATH." }
    }

    if ($audio_files | is-empty) {
        return []
    }

    let filtered = (
        $audio_files 
        | par-each {|file|
            let rate = get-sample-rate $file
            if $rate == null {
                null
            } else if (compare-rates $rate $target_samplerate $operator) {
                { name: $file, rate: $rate }
            } else {
                null
            }
        }
        | compact
    )

    $filtered
}

export def "convert audio rate" [
    target_samplerate: int,      # Target sample rate in Hz (e.g., 22050)
    --suffix: string             # Optional suffix for new files (e.g., "converted")
]: [
    list -> table
] {
    let audio_files = $in
    
    if (which ffmpeg | is-empty) {
        error make { msg: "ffmpeg is required but not found in PATH." }
    }
    
    if ($audio_files | is-empty) {
        return []
    }
    
    let results = ($audio_files | par-each {|file|
        let file_path = ($file | path expand)
        
        if not ($file_path | path exists) {
            {
                name: $file,
                status: "❌",
                reason: "file_not_found",
                old_rate: null,
                new_rate: null,
                old_size: null,
                new_size: null
            }
        } else {
            let old_rate = get-sample-rate $file_path
            let old_size = ($file_path | path expand | ls $in | get size.0)
            
            if $old_rate == null {
                {
                    name: $file,
                    status: "❌",
                    reason: "cannot_read_sample_rate",
                    old_rate: null,
                    new_rate: null,
                    old_size: $old_size,
                    new_size: null
                }
            } else if $old_rate == $target_samplerate {
                {
                    name: $file,
                    status: "😊",
                    reason: "already_target_rate",
                    old_rate: $old_rate,
                    new_rate: $old_rate,
                    old_size: $old_size,
                    new_size: $old_size
                }
            } else {
                # Determine output filename
                let output_file = if ($suffix | is-not-empty) {
                    let stem = ($file_path | path parse | get stem)
                    let extension = ($file_path | path parse | get extension)
                    let parent = ($file_path | path dirname)
                    $parent | path join $"($stem).($suffix).($extension)"
                } else {
                    $file_path
                }
                
                print $"Converting: ($file_path) -> ($output_file) ($old_rate)Hz -> ($target_samplerate)Hz"
                
                # Convert using ffmpeg
                let conversion_result = try {
                    if ($suffix | is-not-empty) {
                        # Create new file with suffix
                        let format = ($file_path | path parse | get extension)
                        ^ffmpeg -y -i $file_path -ar $target_samplerate -f $format $output_file
                    } else {
                        # Replace original file (use temp file for safety)
                        let temp_file = $"($file_path).tmp"
                        let format = ($file_path | path parse | get extension)
                        ^ffmpeg -y -i $file_path -ar $target_samplerate -f $format $temp_file
                        mv $temp_file $output_file
                    }
                    "success"
                } catch { |err|
                    $"ffmpeg_error: ($err.msg)"
                }
                
                if $conversion_result == "success" {
                    let new_rate = get-sample-rate $output_file
                    let new_size = ($output_file | path expand | ls $in | get size.0)
                    
                    {
                        name: $file,
                        status: "✅",
                        reason: "converted",
                        old_rate: $old_rate,
                        new_rate: $new_rate,
                        old_size: $old_size,
                        new_size: $new_size,
                        output_file: $output_file
                    }
                } else {
                    {
                        name: $file,
                        status: "❌",
                        reason: $conversion_result,
                        old_rate: $old_rate,
                        new_rate: null,
                        old_size: $old_size,
                        new_size: null
                    }
                }
            }
        }
    })
    
    # Print summary
    let success_count = ($results | where status == "success" | length)
    let failed_count = ($results | where status == "failed" | length)
    let skipped_count = ($results | where status == "skipped" | length)
    
    notify success $"✅ Conversion complete: ($success_count) converted, ($skipped_count) skipped, ($failed_count) failed"
    print $"✅ Conversion complete: ($success_count) converted, ($skipped_count) skipped, ($failed_count) failed"
    
    $results
}
