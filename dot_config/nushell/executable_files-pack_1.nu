#!/usr/bin/env nu
# Usage:
#   nu files-pack.nu '/path/to/folder' '*.skel.bytes' [--no-zip]
#
# Options:
#   --no-zip: Skip creating the zip archive and keep the temporary folder

def notify [type: string, message: string] {
    let icon = match $type {
        'info' => 'dialog-information'
        'success' => 'dialog-ok'
        'error' => 'dialog-error'
        _ => 'dialog-information'
    }
    ^notify-send --urgency=normal --icon=$icon ($type | str capitalize) $message
}

def main [folder: string, pattern: string, --no-zip] {
    if not ($folder | path exists) or ($folder | path type) != 'dir' {
        notify error $"Directory not found: ($folder)"
        error make { msg: $"❌ Folder does not exist: ($folder)" }
    }

    let base_dir = ($folder | path expand)
    let timestamp = (date now | format date '%Y%m%d_%H%M%S')
    let folder_name = ($base_dir | path basename)
    let temp_dir_name = $"($folder_name)_filtered_structure_($timestamp)"
    let temp_dir = ($env.PWD | path join $temp_dir_name)
    let archive_name = $"($temp_dir_name).zip"
    let archive_path = ($base_dir | path join $archive_name)

    notify info $"Packing files matching ($pattern) from ($base_dir)..."

    # Cleanup temp folder (only if --no-zip is not used)
    if not $no_zip {
        rm -rf $temp_dir
    }
    mkdir $temp_dir

    let files = (glob $"($base_dir)/**/($pattern)")

    if ($files | is-empty) {
        notify error $"No files found matching pattern: ($pattern)"
        error make { msg: "❌ No files found." }
    }

    for file in $files {
        let rel = ($file | path relative-to $base_dir)
        let dest = ($temp_dir | path join $rel)
        mkdir ($dest | path dirname)
        cp $file $dest
    }

    # Archive (only if --no-zip is not used)
    if not $no_zip {
        ^zip -r $archive_path $temp_dir
        notify success $"Archive created: ($archive_path)"
        echo $"✅ Archive created at: ($archive_path)"
    } else {
        notify success $"Files copied to: ($temp_dir)"
        echo $"✅ Files copied to: ($temp_dir)"
    }
}
