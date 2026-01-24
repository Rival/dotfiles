#!/usr/bin/env nu
# Usage:
#   git-find-files-by-commit-hash.nu <commit_hash> <extension> [search_pattern] [--lines-only]
# Example:
#   git-find-files-by-commit-hash.nu 6d92d1 png.meta spriteMode --lines-only
def main [
  commit_hash: string, 
  ext: string, 
  search_pattern?: string,
  --lines-only  # Only include files where lines containing the pattern were changed
] {
  # Check if we're in a git repository
  let git_check = (git rev-parse --show-toplevel | complete)
  if $git_check.exit_code != 0 {
    print "Error: Not in a git repository or git not found"
    return
  }
  
  # Get git root and current directory
  let git_root = ($git_check.stdout | str trim)
  let current_dir = (pwd)
  
  # Change to git root if we're in a subdirectory
  if $git_root != $current_dir {
    print $"Changing to git root: ($git_root)"
    cd $git_root
  }
  
  let ext_pattern = '\.' + ($ext | str replace '.' '\.') + '$'
  let output_file = if $search_pattern != null {
    let suffix = if $lines_only { "_lines_changed" } else { "" }
    $"filtered_files_($ext)_($search_pattern | str replace ' ' '_')($suffix).txt"
  } else {
    $"changed_files_($ext).txt"
  }
  
  let changed_files = (
    git diff-tree --no-commit-id --name-only -r $commit_hash |
    lines |
    where $it =~ $ext_pattern
  )
  
  let filtered = if $search_pattern != null {
    if $lines_only {
      # Check if lines containing the pattern were actually changed
      $changed_files | where {|file|
        try {
          let diff_output = (git show $commit_hash -- $file | complete)
          if $diff_output.exit_code == 0 {
            # Look for added/modified lines (starting with +) that contain the pattern
            $diff_output.stdout | lines | any {|line| 
              ($line | str starts-with "+") and ($line =~ $search_pattern)
            }
          } else {
            false
          }
        } catch {
          false
        }
      }
    } else {
      # Original behavior: check if file contains pattern
      $changed_files | where {|file|
        try {
          let content = (git show $"($commit_hash):($file)" | complete)
          if $content.exit_code == 0 {
            $content.stdout =~ $search_pattern
          } else {
            false
          }
        } catch {
          false
        }
      }
    }
  } else {
    $changed_files
  }
  
  $filtered | save --force $output_file
  print $"Saved ($filtered | length) files to ($output_file)"
  
  if $search_pattern != null and $lines_only {
    print "Note: --lines-only flag used - only files with changed lines containing the pattern are included"
  }
}
