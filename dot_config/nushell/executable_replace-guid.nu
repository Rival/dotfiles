#!/usr/bin/env nu
# Usage: nu replace-guid.nu old_guid new_guid
def main [old: string, new: string, path: string = "."] {
  print $"🔍 Replacing guid ($old) → ($new) in ($path)..."
  
  # Check if the path exists
  if not ($path | path exists) {
    print $"❌ Error: Path ($path) does not exist"
    return
  }
  
  # Use glob to find files, with error handling
  let files = try {
    glob $"($path)/**/*.{meta,unity,mat,asset,prefab}" | where ($it | path exists)
  } catch {
    print $"❌ No matching files found in ($path)"
    return
  }
  
  if ($files | is-empty) {
    print $"❌ No .meta, .unity, .mat, .asset, or .prefab files found in ($path)"
    return
  }
  
  let updated_files = $files
  | each {|f|
      # Try to open as text, skip if binary
      let content = try { 
        open $f --raw | decode utf-8 
      } catch { 
        # Skip binary files
        return 0
      }
      
      if ($content | str contains $old) {
          print $"✏️  Updating ($f)"
          $content | str replace -a $old $new | save -f $f
          1
      } else {
          0
      }
  }
  | math sum
  
  print $"✅ Replacement complete. ($updated_files) files updated"
}
