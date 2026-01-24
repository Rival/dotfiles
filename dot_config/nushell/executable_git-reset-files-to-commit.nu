#!/usr/bin/env nu
# Usage:
#   git-reset-files-to-commit.nu <commit_hash> <file_list_txt> [--dry-run]
# Example:
#   git-reset-files-to-commit.nu 6d92d1 filtered_files_png.meta_spriteMode_lines_changed.txt
#   git-reset-files-to-commit.nu 6d92d1 filtered_files_png.meta_spriteMode_lines_changed.txt --dry-run
def main [
  commit_hash: string,
  file_list: string,
  --dry-run  # Show what would be done without actually doing it
] {
  # Check if we're in a git repository
  let git_check = (git rev-parse --show-toplevel | complete)
  if $git_check.exit_code != 0 {
    print "Error: Not in a git repository or git not found"
    return
  }
  
  # Get git root and change to it
  let git_root = ($git_check.stdout | str trim)
  let current_dir = (pwd)
  
  if $git_root != $current_dir {
    print $"Changing to git root: ($git_root)"
    cd $git_root
  }
  
  # Check if file list exists
  if not ($file_list | path exists) {
    print $"Error: File list '($file_list)' not found"
    return
  }
  
  # Read the file list
  let files = (open $file_list | lines | where $it != "")
  
  if ($files | length) == 0 {
    print $"No files found in ($file_list)"
    return
  }
  
  print $"Found ($files | length) files to reset to commit ($commit_hash)"
  
  if $dry_run {
    print "DRY RUN - would reset these files:"
    $files | each {|file| print $"  ($file)"}
    print ""
    print $"Command that would be executed:"
    print $"  git checkout ($commit_hash) -- ($files | str join ' ')"
  } else {
    print "Resetting files..."
    
    # Check if commit exists
    let commit_check = (git rev-parse --verify $commit_hash | complete)
    if $commit_check.exit_code != 0 {
      print $"Error: Commit '($commit_hash)' not found"
      return
    }
    
    # Reset each file individually to handle potential errors better
    let results = $files | each {|file|
      let result = (git checkout $commit_hash -- $file | complete)
      {
        file: $file,
        success: ($result.exit_code == 0),
        error: $result.stderr
      }
    }
    
    let successful = ($results | where success == true)
    let failed = ($results | where success == false)
    
    print $"Successfully reset ($successful | length) files"
    
    if ($failed | length) > 0 {
      print $"Failed to reset ($failed | length) files:"
      $failed | each {|item| 
        print $"  ($item.file): ($item.error | str trim)"
      }
    }
    
    # Show git status
    print ""
    print "Git status after reset:"
    git status --porcelain
  }
}
