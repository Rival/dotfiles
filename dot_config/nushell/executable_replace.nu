#!/usr/bin/env nu

# Replace text in files with specific extension and log changes
# Usage: nu text-replace.nu <extension> <old_text> <new_text>
# Example: nu text-replace.nu txt "hello world" "goodbye world"

def main [extension: string, old_text: string, new_text: string] {
    # Remove leading dots if present
    let clean_ext = if ($extension | str starts-with '.') {
        $extension | str substring 1..
    } else {
        $extension
    }
    let pattern = $"**/*.($clean_ext)"
    let files_changed = []
    
    print $"Searching for files with extension: .($clean_ext)"
    print $"Replacing: '($old_text)' -> '($new_text)'"
    print ""
    
    let files = glob $pattern
    
    if ($files | length) == 0 {
        print $"No files found with extension .($clean_ext)"
        return
    }
    
    print $"Found ($files | length) files to check..."
    print ""
    
    mut changed_count = 0
    
    for file in $files {
        let original_content = open $file
        let new_content = $original_content | str replace -a $old_text $new_text
        
        if $original_content != $new_content {
            $new_content | save -f $file
            print $"✓ Replaced text in: ($file)"
            $changed_count = $changed_count + 1
        }
    }
    
    print ""
    if $changed_count > 0 {
        print $"✅ Successfully replaced text in ($changed_count) files"
    } else {
        print $"ℹ️  No files contained the text '($old_text)'"
    }
}
