# env.nu
#
# Installed by:
# version = "0.104.0"
#
# Previously, environment variables were typically configured in `env.nu`.
# In general, most configuration can and should be performed in `config.nu`
# or one of the autoload directories.
#
# This file is generated for backwards compatibility for now.
# It is loaded before config.nu and login.nu
#
# See https://www.nushell.sh/book/configuration.html
#
# Also see `help config env` for more options.
#
# You can remove these comments if you want or leave
# them for future reference.

$env.ENABLE_LSP_TOOL = "1"
$env.DOTNET_RUNTIME_ID = "linux-x64"

# pi-lens: large Unity project needs bigger walk budget
# Assets tree + 168k tracked files (~200k+ dir entries); default 50k aborts
# language detection and breaks word-index/review-graph entirely.
$env.PI_LENS_STARTUP_SCAN_MAX_ENTRIES = "300000"
$env.PI_LENS_REVIEW_GRAPH_MAX_FILES = "8000"
# review-graph has ~300k elements (nodes+edges) for this repo; default persist
# cap is 200k, which skips disk persistence -> full 6-min cold rebuild every
# restart. Raise so the graph is cached and loads in ~20ms next time.
$env.PI_LENS_GRAPH_PERSIST_MAX_ELEMENTS = "400000"

# Slack watcher (pi extension): user token read from secret file at shell start.
# Never hardcode the xoxp- token here — this file is synced to GitHub via chezmoi.
if ("~/.agents/secrets/slack-user-token" | path expand | path exists) {
    $env.SLACK_WATCHER_TOKEN = (open --raw ("~/.agents/secrets/slack-user-token" | path expand) | str trim)
}

