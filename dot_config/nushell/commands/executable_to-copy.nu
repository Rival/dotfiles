export def "to copy" [
    --destination (-d): string,   # Target directory to copy files to (optional - will auto-generate if not provided)
    --flat,                       # Copy files without preserving directory structure
    --base-dir: string,           # Base directory for relative path calculations (defaults to PWD)
    --create-dest                 # Create destination directory if it doesn't exist (auto-enabled when destination is auto-generated)
] {
    # Get files using the get filenames helper
    let file_list = ($in | to filenames)

    if ($file_list | is-empty) {
        notify error "No files provided to copy"
        error make { msg: "❌ No files provided." }
    }

    # Determine base directory for relative path calculations
    let base_dir = if ($base_dir | is-not-empty) {
        $base_dir | path expand
    } else {
        $env.PWD
    }
    
    # Generate destination directory if not provided
    let dest_dir = if ($destination | is-not-empty) {
        $destination | path expand
    } else {
        # Auto-generate destination folder name
        let timestamp = (date now | format date '%Y%m%d_%H%M%S')
        let folder_name = ($base_dir | path basename)
        $env.PWD | path join $"($folder_name)_copy_($timestamp)"
    }
    
    # Auto-enable create-dest when destination is auto-generated
    let should_create_dest = ($create_dest) or ($destination | is-empty)
    
    if ($should_create_dest) and not ($dest_dir | path exists) {
        mkdir $dest_dir
        notify info $"Created destination directory: ($dest_dir)"
    }
    
    if not ($dest_dir | path exists) {
        notify error $"Destination directory not found: ($dest_dir)"
        error make { msg: $"❌ Destination directory does not exist: ($dest_dir)" }
    }
    
    if ($dest_dir | path type) != 'dir' {
        notify error $"Destination is not a directory: ($dest_dir)"
        error make { msg: $"❌ Destination is not a directory: ($dest_dir)" }
    }
    
    notify info $"Copying ($file_list | length) files to ($dest_dir)..."
    if ($flat) {
        notify info "Using flat structure (no subdirectories)"
    } else {
        notify info "Preserving directory structure"
    }
    
    # Process files and collect results
    let results = ($file_list | par-each { |file|
        let file_path = ($file | path expand)
        
        if not ($file_path | path exists) {
            notify error $"File not found: ($file_path)"
            { status: "failed", file: $file_path, reason: "not_found" }
        } else {
            print $"Copying: ($file_path)"
            
            let dest_file = if ($flat) {
                # Flat copy - just use filename
                $dest_dir | path join ($file_path | path basename)
            } else {
                # Preserve structure - calculate relative path
                let base_dir_clean = ($base_dir | path expand)
                let rel_path = if ($file_path | str starts-with $base_dir_clean) {
                    # File is within base_dir, get relative path
                    let base_len = ($base_dir_clean | str length)
                    let rel_path = ($file_path | str substring ($base_len)..)
                    # Remove leading slash if present
                    if ($rel_path | str starts-with "/") {
                        $rel_path | str substring 1..
                    } else {
                        $rel_path
                    }
                } else {
                    # File is outside base_dir, use just the filename
                    $file_path | path basename
                }
                $dest_dir | path join $rel_path
            }
            
            # Create destination directory if needed
            let dest_file_dir = ($dest_file | path dirname)
            if not ($dest_file_dir | path exists) {
                mkdir $dest_file_dir
            }
            
            # Copy the file
            try {
                cp $file_path $dest_file
                { status: "success", file: $file_path, dest: $dest_file }
            } catch {
                notify error $"Failed to copy: ($file_path)"
                { status: "failed", file: $file_path, reason: "copy_error" }
            }
        }
    })
    
    let copied_count = ($results | where status == "success" | length)
    let failed_count = ($results | where status == "failed" | length)
    
    notify success $"Copy complete: ($copied_count) files copied, ($failed_count) failed"
    print $"✅ Copied ($copied_count) files to ($dest_dir)"
    if ($failed_count > 0) {
        print $"⚠️  ($failed_count) files failed to copy"
    }
    
    # Return summary
    {
        destination: $dest_dir,
        copied: $copied_count,
        failed: $failed_count,
        total: ($file_list | length)
    }
}
