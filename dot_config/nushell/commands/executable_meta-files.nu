# Usage: ls *.mp3 | rename-meta-files ogg
# or: [file1.mp3, file2.mp3] | rename-meta-files wav

export def "rename meta file ext" [new_extension: string] {
    # Get files using the get filenames helper
    let file_list = ($in | get filenames)
    if ($file_list | is-empty) {
        notify error "No files provided to copy"
        error make { msg: "❌ No files provided." }
    }
    
    let results = ($file_list | par-each {|file|
        let file_path = ($file | path expand)
        let file_dir = ($file_path | path dirname)
        let file_stem = ($file_path | path parse | get stem)
        let current_ext = ($file_path | path parse | get extension)
        
        # Construct the current meta file path
        let current_meta = ($file_dir | path join $"($file_stem).($current_ext).meta")
        
        # Construct the new meta file path
        let new_meta = ($file_dir | path join $"($file_stem).($new_extension).meta")
        
        # Check if the current meta file exists
        if ($current_meta | path exists) {
            try {
                mv $current_meta $new_meta
                {
                    file: $file,
                    current_meta: $current_meta,
                    new_meta: $new_meta,
                    status: "✅ Success",
                    message: "Renamed successfully"
                }
            } catch { |err|
                {
                    file: $file,
                    current_meta: $current_meta,
                    new_meta: $new_meta,
                    status: "❌ Error",
                    message: $"Failed to rename: ($err.msg)"
                }
            }
        } else {
            {
                file: $file,
                current_meta: $current_meta,
                new_meta: $new_meta,
                status: "⚠️ Not Found",
                message: "Meta file does not exist"
            }
        }
    })
    
    # Return the results as a table
    $results
}
