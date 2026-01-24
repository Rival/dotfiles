# config.nu
#
# Installed by:
# version = "0.103.0"
#
# This file is used to override default Nushell settings, define
# (or import) custom commands, or run any other startup tasks.
# See https://www.nushell.sh/book/configuration.html
#
# This file is loaded after env.nu and before login.nu
#
# You can open this file in your default editor using:
# config nu
#
# See `help config nu` for more options
#
# You can remove these comments if you want or leave
# them for future reference.
# plugin add /home/andrei/.cargo/bin/nu_plugin_mongo
# plugin use /home/andrei/.cargo/bin/nu_plugin_mongo

$env.SHELL = "/usr/bin/nu"
$env.QMLLS_CONFIG = "~/.config/qmlls/qmlls.ini"
$env.QML_IMPORT_PATH = "/usr/lib/qt6/qml:/usr/lib/qt6/qml/Quickshell"
$env.PATH = ($env.PATH | split row (char esep) | append /usr/lib/qt6/bin | append $"($env.HOME)/.local/share/nvim/mason/bin" | append $"($env.HOME)/.local/npm-global/bin")
# $env.PATH = ($env.PATH | split row (char esep) | append "/home/andrei/.cargo/bin" | str join (char esep))
# source fzf_1.nu
fastfetch
oh-my-posh init nu
# zoxide init nushell | save -f ~/.zoxide.nu
# Initialize zoxide only if installed
if (which zoxide | is-not-empty) {
    zoxide init --cmd cd nushell | save -f ~/.config/zoxide.nu
}
# mkdir ($nu.data-dir | path join "vendor/autoload")

def --env activate-venv [] {
  $env.VIRTUAL_ENV = (pwd | path join "venv")
  $env.PATH = ($env.PATH | prepend ($env.VIRTUAL_ENV | path join "bin"))
}

# Aliases
alias v = nvim
alias sv = sudo -E nvim
def vi [...args] {
    ^sh -c $"nohup neovide ($args | str join ' ') >/dev/null 2>&1 &"
}
def svi [...args] {
    # Now run the GUI editor with sudo -E and background
    ^sh -c $"nohup sudo -E neovide ($args | str join ' ') >/dev/null 2>&1 &"
}
alias sysupdate = yay -Syu
# checks app in yay repositories
alias yayq = yay -q
# clean yay cache
alias yays = yay -Scc
alias yayr = yay -R
## disk space analyzing util
alias disk-usage = ncdu / --exclude /mnt --exclude /run/timeshift
alias vim-log = nvim +':set autoread | autocmd CursorHold * checktime' /home/andrei/.local/state/nvim/lsp.log
alias log-tail = nvim +':set autoread | autocmd CursorHold * checktime' 
alias scr = cd ~/.scripts
alias cfg = cd ~/.config
alias macmini = ssh Intellectokids@192.168.1.34
alias ngit = nvim +Neogit
alias git-submodule-update = git submodule update --init --recursive 
alias git-panda = lazygit -p ~/Work/Panda
alias git-panda1 = lazygit -p ~/Work/Panda1
alias git-panda2 = lazygit -p ~/Work/Panda2
alias log-tail2 = lnav 
alias btrfs-status = btrfs device stats /
alias btrfs-usage-calculate-snapshots = sudo btrfs filesystem du /run/timeshift/backup/timeshift-btrfs/snapshots
alias plasma-logout = qdbus org.kde.Shutdown /Shutdown logout

alias h-submap-reset = hyprctl dispatch submap reset
# alias pk = ps | fzf | split row "│" | get 2 | str trim | into int | kill $in
alias connect-mongo-intellectokids = ssh -i ~/.ssh/document-db-tunnel-key.pem -N -L 27017:prod-docdb.cluster-cojqzcfnokt7.eu-west-1.docdb.amazonaws.com:27017 ec2-user@54.171.148.145

#yazi
def --env y [...args] {
  # kitty @ set-background-image /home/andrei/Documents/background_16on9.png
	let tmp = (mktemp -t "yazi-cwd.XXXXXX")
	yazi ...$args --cwd-file $tmp
	let cwd = (open $tmp)
	if $cwd != "" and $cwd != $env.PWD {
		cd $cwd
	}
	rm -fp $tmp
  # kitty @ set-background-image none
}
def --env sy [...args] {
	let tmp = (mktemp -t "yazi-cwd.XXXXXX")
	sudo -E yazi ...$args --cwd-file $tmp
	let cwd = (open $tmp)
	if $cwd != "" and $cwd != $env.PWD {
		cd $cwd
	}
	rm -fp $tmp
}
# This sets the full prompt including username, host, path, and time
# def prompt [] {
#     let user = (whoami)
#     let host = (hostname)
#     let path = (pwd | path basename)
#     let time = (date now | date format "%H:%M:%S")
#     let line1 = $"┬─[\($user)@\(host):\(path)]─[\(time)]"
#     let line2 = "╰─>$ "
#     $"($line1)\n($line2)"
# }

# def kube_prompt [] {
#     let k_prompt =  ([(kubectl ctx -c), (kubectl ns -c)] | str trim | str join '/')
#     let d_prompt = ([(date now | date format '%r')] | str join)
#     $"\(($k_prompt)\) ($d_prompt)"
# }

# Nushell uses this to decide what character to use at the end (ignored here)
# def prompt_indicator [] { "" }
# def prompt_multiline_indicator [] { "::: " }
# let-env PROMPT_COMMAND_RIGHT = { kube_prompt }

$env.config.edit_mode = 'vi'
$env.config.hooks = {
    # pre_prompt: [{ print "pre prompt hook" }]
    # pre_execution: [{ print "pre exec hook" }]
    # env_change: {
    #     PWD: [{|before, after| print $"changing directory from ($before) to ($after)" }]
    # }
    command_not_found: {
            |cmd_name| (
                try {
                    let pkgs = (pkgfile --binaries --verbose $cmd_name)
                    if ($pkgs | is-empty) {
                        return null
                    }
                    (
                        $"(ansi $env.config.color_config.shape_external)($cmd_name)(ansi reset) " +
                        $"may be found in the following packages:\n($pkgs)"
                    )
                }
            )
        }
}

# def jeg [pattern] {
#     journalctl -xe | grep $pattern
# }

# Quick system-wide Claude helper
def claude-system [] {
  cd ~/.claude-system-wide
  claude
}

# Quick system-wide Claude helper
def glm-system [] {
  cd ~/.claude-system-wide
  claude-glm
}

def ask [question: string] {
  claude -p $question
}

# Update dotfiles from GitHub and apply
def dotfiles-update [] {
  print "📥 Pulling dotfiles from GitHub..."
  cd ~/.local/share/chezmoi
  git pull
  print "📦 Applying changes..."
  chezmoi apply
  print "✅ Dotfiles updated!"
}

def pk [] {
    let selection = (ps | fzf)
    if ($selection | is-empty) {
        print "Cancelled"
        return
    }
    
    let pid = ($selection | split row "│" | get 2 | str trim | into int)
    kill $pid
}
def pk2 [] {
    ^ps -o pid,etime,cmd -u $env.USER
    | tail -n +2
    | fzf
    | split row " "
    | get 0
    | into int
    | kill $in
}
def pk3 [] {
    let selection = (
        ps 
        # | table -i false
        | insert cwd { |row| 
            try { ^readlink $"/proc/($row.pid)/cwd" } catch { "?" }
        }
        | select pid name cwd cpu mem
        | fzf
    )
    
    if ($selection | is-empty) {
        return
    }
    
    let pid = ($selection | split row "│" | get 1 | str trim | into int)
    kill $pid
}

# Completion command
def locations [] { ['Work', "Downloads", "Documents" ] }
# Command to be completed
def --env go [folder: string@locations] { cd ($env.HOME | path join $folder)}

def apps [] { ["unity", "yazi", "kitty", "steam" ] }
# journal
def journal-errors [pattern: string@apps] {
    journalctl -xe | grep $pattern
}
 # journal with tailing
def journalt [pattern: string@apps] {
    journalctl -f | grep --line-buffered $pattern
}
# journal with tailing
# alias journalt = journalctl -f | grep --line-buffered 
# def actions [] { [
#     {value: "-S", description: "Install app"},
#     {value: "-Rns", description: "Delete app"},
#     {value: "-q", description: "Check app"}
# ] }
def flags [] { [
    "-S",
    "-Rns",
    "-q"] }
# def --env yy [
# action: string@params
# # appName: sring@actions
# ] {
#     yay $flag #$appName 
#   }
def --env yy [flag: string@flags] {yay ($flag)}
# $env.config.completions.external = {
#     enable: true
#     max_results: 100
#     completer: $completer
# }
let fish_completer = {|spans|
    fish --command $"complete '--do-complete=($spans | str join ' ')'"
    | from tsv --flexible --noheaders --no-infer
    | rename value description
    | update value {
        if ($in | path exists) {$'"($in | str replace "\"" "\\\"" )"'} else {$in}
    }
}
$env.config = {
    completions: {
        external: {
            enable: true
            completer: $fish_completer
        }
    }
}
# $env.config.keybindings = [
#     {
#       name: fuzzy_history_fzf
#       modifier: control
#       keycode: char_r
#       mode: [emacs , vi_normal, vi_insert]
#       event: {
#         send: executehostcommand
#         cmd: "commandline edit --replace (
#         history
#         | where exit_status == 0
#         | get command
#         | reverse
#         | uniq
#         | str join (char -i 0)
#         | fzf --scheme=history --read0 --tiebreak=chunk --layout=reverse --preview='echo {..}' --preview-window='bottom:3:wrap' --bind alt-up:preview-up,alt-down:preview-down --height=70% -q (commandline) --preview='echo -n {} | nu --stdin -c \'nu-highlight\''
#         | decode utf-8
#         | str trim
#         )"
#       }
#     }
# ]
# $env.config.keybindings = [
#   {
#     name: fuzzy_history
#     modifier: control
#     keycode: char_r
#     mode: [emacs, vi_normal, vi_insert]
#     event: [
#       {
#         send: ExecuteHostCommand
#         cmd: "do {
#           $env.SHELL = ^/usr/bin/bash
#           commandline edit --insert (
#             history
#             | get command
#             | reverse
#             | uniq
#             | str join (char -i 0)
#             | fzf --scheme=history 
#                 --read0
#                 --layout=reverse
#                 --height=40%
#                 --bind 'ctrl-/:change-preview-window(right,70%|right)'
#                 --preview='echo -n {} | nu --stdin -c \'nu-highlight\''
#                 # Run without existing commandline query for now to test composability
#                 # -q (commandline)
#             | decode utf-8
#             | istr trim
#           )
#         }"
#       }
#     ]
#   }
# ]#   {
#     name: fuzzy_history
#     modifier: control
#     keycode: char_r
#     mode: [emacs, vi_normal, vi_insert]
#     event: [
#       {
#         send: ExecuteHostCommand
#         cmd: "commandline edit (
#           history
#             | get command
#             | reverse
#             | uniq
#             | str join (char -i 0)
#             | fzf
#               --preview '{}'
#               --preview-window 'right:30%'
#               --scheme history
#               --read0
#               --layout reverse
#               --height 40%
#               --query (commandline)
#             | decode utf-8
#             | str trim
#         )"
#       }
#     ]
#   }
# ]
# working
$env.config.keybindings = [
  {
    name: fuzzy_history
    modifier: control
    keycode: char_r
    mode: [emacs, vi_normal, vi_insert]
    event: [
      {
        send: ExecuteHostCommand
        cmd: "do {
        $env.SHELL = \"/usr/bin/bash\"
        commandline edit (
        history
        | get command
        | reverse
        | uniq
        | str join (char -i 0)
        | fzf --scheme=history 
        -e
        --read0
        --layout=reverse
        --height=40%
        --bind 'ctrl-/:change-preview-window(right,70%|right)'
        --preview='echo -n {} | nu --stdin -c \'nu-highlight\''
        -q (commandline)
        | decode utf-8
        | str trim
        )
        }"
      }
    ]
  },
  {
    name: fuzzy_history_replace
    modifier: control_alt
    keycode: char_r
    mode: [emacs, vi_normal, vi_insert]
    event: [
      {
        send: ExecuteHostCommand
        cmd: "do {
        $env.SHELL = \"/usr/bin/bash\"
        commandline edit --insert (
        history
        | get command
        | reverse
        | uniq
        | str join (char -i 0)
        | fzf --scheme=history 
        -e
        --read0
        --layout=reverse
        --height=40%
        --bind 'ctrl-/:change-preview-window(right,70%|right)'
        --preview='echo -n {} | nu --stdin -c \'nu-highlight\''
        # Run without existing commandline as its replacing command line text
        # -q (commandline)
        | decode utf-8
        | str trim
        )
        }"
      }
    ]
  },
  {
    name: fuzzy_files
    modifier: control_alt
    keycode: space
    mode: [emacs, vi_normal, vi_insert]
    event: [
      {
        send: ExecuteHostCommand
        cmd: "do {
        $env.SHELL = \"/usr/bin/bash\"
        commandline edit --insert (
        ls **/* 
        | get name
        | str join (char -i 0)
        | fzf --read0
        --layout=reverse
        --height=40%
        --prompt='Files> '
        --preview='if (ls {} | length) > 0 { ls {} } else { cat {} | lines | first 50 }'
        -q (commandline)
        | decode utf-8
        | str trim
        )
        }"
      }
    ]
  },
]

$env.config.show_banner = false
$env.config.cursor_shape = {
    vi_insert: line
    vi_normal: block
    emacs: line
  }
$env.config.color_config = {
  separator: white
  leading_trailing_space_bg: { attr: n }
  header: green_bold
  empty: blue
  bool: light_cyan
  int: red
  filesize: cyan
  duration: white
  datetime: purple
  range: white
  float: white
  string: white
  nothing: white
  binary: white
  cell-path: white
  row_index: green_bold
  record: white
  list: white
  closure: green_bold
  glob:cyan_bold
  block: white
  # hints: light_gray
  hints: white_dimmed
  search_result: { bg: red fg: white }
  shape_binary: purple_bold
  shape_block: blue_bold
  shape_bool: light_cyan
  shape_closure: green_bold
  shape_custom: green
  shape_datetime: cyan_bold
  shape_directory: cyan
  shape_external: cyan
  shape_external_resolved: light_yellow_bold
  shape_externalarg: green_bold
  shape_filepath: cyan
  shape_flag: blue_bold
  shape_float: purple_bold
  shape_glob_interpolation: cyan_bold
  shape_globpattern: cyan_bold
  shape_int: purple_bold
  shape_internalcall: cyan_bold
  shape_keyword: cyan_bold
  shape_list: cyan_bold
  shape_literal: blue
  shape_match_pattern: green
  shape_matching_brackets: { attr: u }
  shape_nothing: light_cyan
  shape_operator: yellow
  shape_pipe: purple_bold
  shape_range: yellow_bold
  shape_raw_string: light_purple
  shape_record: cyan_bold
  shape_redirection: purple_bold
  shape_signature: green_bold
  shape_string: green
  shape_string_interpolation: cyan_bold
  shape_table: blue_bold
  shape_vardecl: purple
  shape_variable: purple
  shape_garbage: {
    fg: white
    bg: red
    attr: b
  }
}
$env.QMK_HOME = $"($env.HOME)/Repositories/qmk"
# def qmk-run [...args: string] { 
#     ^"$env.QMK_HOME/.venv/bin/qmk" ...$args
# }
alias qmk-run = ^"/home/andrei/Repositories/qmk/.venv/bin/qmk"
def notify [type: string, message: string] {
    let icon = match $type {
        'info' => 'dialog-information'
        'success' => 'dialog-ok'
        'error' => 'dialog-error'
        _ => 'dialog-information'
    }
    ^notify-send --urgency=normal --icon=$icon ($type | str capitalize) $message
}

def mount-usb [
  label: string = "RPI-RP2"
]: nothing -> string {
  # Find device
  let device = (lsblk -o NAME,FSTYPE,MOUNTPOINT,LABEL -J | from json | get blockdevices | 
    each { |dev| 
        if "children" in $dev { 
            $dev.children 
        } else { 
            [] 
        } 
    }
    | flatten 
    | where label == $label
    | get name 
    | get 0?)
    
  if ($device == null) {
    error make { msg: $"❌ No USB device found with label ($label)" }
  }
  
  let device_path = $"/dev/($device)"
  print $"🔄 Mounting ($device_path) with label ($label) ..."
  
  # Mount using udisksctl (no sudo needed)
  let result = (udisksctl mount -b $device_path | complete)
  
  if $result.exit_code != 0 {
    error make { msg: $"❌ Failed to mount: ($result.stderr)" }
  }
  
  # Extract mount point from udisksctl output
  # Output looks like: "Mounted /dev/sdd1 at /run/media/andrei/RPI-RP2"
  let mount_point = ($result.stdout | str replace --regex ".*at " "" | str trim)
  print $"✅ Mounted at ($mount_point)"
  $mount_point
}

def copy-to-usb [
  source_path: string   # File or directory to copy
  label: string = "RPI-RP2"  # USB device label
]: nothing -> nothing {
  
  # Check if source exists
  if not ($source_path | path exists) {
    error make { msg: $"❌ Source path does not exist: ($source_path)" }
  }
  
  # Mount the USB device
  let mount_point = (mount-usb $label)
  
  # Copy the file/directory
  let filename = ($source_path | path basename)
  let destination = ($mount_point | path join $filename)
  
  print $"🔄 Copying ($source_path) to ($destination)..."
  
  try {
    if ($source_path | path type) == "dir" {
      cp -r $source_path $mount_point
    } else {
      cp $source_path $mount_point
    }
    print $"✅ Successfully copied to USB"
  } catch { |err|
    print $"❌ Copy failed: ($err.msg)"
    error make { msg: "Copy operation failed" }
  }
  
  # Sync to ensure data is written
  print "🔄 Syncing data..."
  sync
}

def write-firmware-vial-to-usb [] {
 copy-to-usb /home/andrei/Repositories/vial-qmk/keyball_keyball39_vial.uf2 
}


# Source zoxide only if file exists
if ("~/.config/zoxide.nu" | path expand | path exists) {
    source ~/.config/zoxide.nu
}
source ~/.config/nushell/completion-external.nu
use commands *
# glob commands/*.nu | each { |file| source $file }
# ls commands/*.nu | each { |file| source $file.name }
# source commands/to-utils.nu
# source commands/to-test.nu
# source commands/to-copy.nu
# source commands/to-zip.nu
# source commands/rename-meta-files.nu
# Create a reload command in your config
def reload-commands [] {
    use commands *
}
