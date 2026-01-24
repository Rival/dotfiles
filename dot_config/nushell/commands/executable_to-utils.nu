export def "to filenames" []: [
  list -> list
] {
    # Handle input from pipe (ls table) or direct list
    let file_list = if ($in | describe | str contains 'table') {
        # From ls command - extract name column
        if 'name' in ($in | columns) {
            $in | get name
        } else {
            error make { msg: "❌ Table input must have 'name' column" }
        }
    } else if ($in | describe | str contains 'list') {
        # Direct list of files
        $in
    } else {
        error make { msg: "❌ Input must be a table (from ls) or list of files" }
    }
    
    $file_list
}
