export def main [
    folder?: string,              # Base directory for files (defaults to PWD)
    --flat                        # Zip files without preserving directory structure
] {
    # Get files using the get filenames helper
    let file_list = ($in | to filenames)

    if ($file_list | is-empty) {
        notify error "No files provided to zip"
        error make { msg: "❌ No files provided." }
    }
    
    # Determine base_dir
    let base_dir = if ($folder | is-not-empty) {
        $folder | path expand
    } else {
        $env.PWD 
    }
    
    if not ($base_dir | path exists) or ($base_dir | path type) != 'dir' {
        notify error $"Directory not found: ($base_dir)"
        error make { msg: $"❌ Folder does not exist: ($base_dir)" }
    }
    
    let timestamp = (date now | format date '%Y%m%d_%H%M%S')
    let folder_name = ($base_dir | path basename)
    let archive_name = $"($folder_name)_zipped_files_($timestamp).zip"
    let archive_path = ($env.PWD | path join $archive_name)
    let temp_dir = ($env.PWD | path join $"($folder_name)_temp_zip_($timestamp)")
    
    notify info $"Zipping ($file_list | length) files from ($base_dir)..."
    
    # Cleanup temp folder if it exists
    if ($temp_dir | path exists) {
        rm -rf $temp_dir
    }
    
    # Use the to-copy function to copy files to temp directory
    let copy_result = if ($flat) {
        $file_list | to copy --destination $temp_dir --create-dest --flat --base-dir $base_dir
    } else {
        $file_list | to copy --destination $temp_dir --create-dest --base-dir $base_dir
    }
    
    if ($copy_result.failed > 0) {
        notify warning $"Some files failed to copy, continuing with ($copy_result.copied) files..."
    }
    
    if ($copy_result.copied == 0) {
        rm -rf $temp_dir
        notify error "No files were successfully copied"
        error make { msg: "❌ No files to zip." }
    }
    
    # Create archive
    notify info "Creating ZIP archive..."
    ^zip -r $archive_path $temp_dir
    
    # Cleanup temp folder
    rm -rf $temp_dir
    
    notify success $"Archive created: ($archive_path)"
    print $"✅ Archive created at: ($archive_path)"
    print $"   Contains ($copy_result.copied) files"
    
    # Return archive info
    {
        archive_path: $archive_path,
        files_count: $copy_result.copied,
        failed_count: $copy_result.failed
    }
}
