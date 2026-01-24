#!/usr/bin/env nu
#  *   *           *       *             
# | | | |_ **   **| | ** *****| |***** **_  ___  
# | | | | '_ \ / ` |/ ` | __/ * \/ *_| 
# | |_| | |_) | (_| | (_| | ||  **/\** \ 
#  \___/| .__/ \__,_|\__,_|\__\___||___/ 
#       |_|                              

# Check if command exists
def check_command_exists [cmd: string] {
    try {
        which $cmd | is-not-empty
    } catch {
        false
    }
}

# Get script name and check for multiple instances
let script_name = ($env.PWD | path join $env.FILE_PWD | path basename)
let instance_count = (ps | where name =~ $script_name | length)

if $instance_count > 1 {
    sleep ($instance_count * 1sec)
}

# Define thresholds for color indicators
let threshold_green = 0
let threshold_yellow = 25
let threshold_red = 100

# Check for updates (Arch only)
let updates = if (check_command_exists "pacman") {
    # Check for lock files
    let pacman_lock = "/var/lib/pacman/db.lck"
    let user_id = (id -u | into string | str trim)
    let checkup_lock = $"($env.TMPDIR? | default "/tmp")/checkup-db-($user_id)/db.lck"
    
    # Wait for lock files to be released
    while ($pacman_lock | path exists) or ($checkup_lock | path exists) {
        sleep 1sec
    }
    
    # Get update count
    try {
         ^yay -Qu | lines | length
    } catch {
        0
    }
} else {
    0
}

# Determine CSS class based on thresholds
let css_class = if $updates > $threshold_red {
    "red"
} else if $updates > $threshold_yellow {
    "yellow"
} else {
    "green"
}

# Output JSON format for Waybar
if $updates != 0 {
    if $updates > $threshold_green {
        {
            text: ($updates | into string),
            alt: ($updates | into string),
            tooltip: "Click to update your system",
            class: $css_class
        } | to json --raw
    } else {
        {
            text: "0",
            alt: "0", 
            tooltip: "No updates available",
            class: "green"
        } | to json --raw
    }
} else {
    {
        text: "0",
        alt: "0",
        tooltip: "No updates available", 
        class: "green"
    } | to json --raw
}
