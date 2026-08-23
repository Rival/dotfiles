# yatline-extra.yazi

Local fork of [imsi32/yatline](https://github.com/imsi32/yatline) (rev c5d4b48) with
**multiple extra info lines**. Not managed by `ya pkg` → survives `ya pkg upgrade`.

## What's different from upstream

- Up to **N extra lines** anywhere in the layout: positions `"extra1"`…`"extraN"`
  (bare `"extra"` = `"extra1"`) in `component_positions`.
- Config: `extra_lines = { {left=…, right=…}, … }` — each entry is a regular
  `LineConfig` (section_a/b/c × string/line/coloreds components), same as
  `header_line`/`status_line`.
- `display_extra_line` toggles all extra lines at once; an empty/unconfigured
  line is skipped automatically (no ghost row).
- Bug fix: config merge now uses `~= nil` instead of truthiness, so boolean
  options defaulting to `false` can be overridden from user config.
- **Disk-aware tab names**: when tabs sit on different disks/volumes, each tab
  gets an `icon+role` prefix (e.g. `2 🪟 Windows/Downloads`) from
  `disk-names.lua` (same table as disk-bar). Same disk everywhere → no prefix.
  The mount table is read once from `/proc/self/mounts` (no subprocess per
  render). Config: `tab_disk_names = true` (default), `disk_names = <table>`
  in setup; per-tab width grows by the prefix length.
- Extra lines are rendered by a plain-Lua `ExtraLine` widget following yazi's
  preset component pattern (`Root:redraw()` calls `ui.redraw()` on children).

## Example

```lua
require("yatline-extra"):setup({
    display_extra_line = true,
    component_positions = { "header", "extra1", "tab", "status" },
    extra_lines = {
        {   -- extra1 (top): dir size · cwd · counts · Σ selection size
            left  = { section_a = {}, section_b = {}, section_c = {
                { type = "coloreds", name = "dir-size" },
                { type = "string", name = "tab_path", params = { true, 60, 25 } },
                { type = "coloreds", name = "count", params = { false, true } },
                { type = "coloreds", name = "sel-size" },
            } },
            right = { section_a = {}, section_b = {}, section_c = {} },
        },
    },
    -- …header_line / status_line / styles as usual…
})
```

Add more lines by appending entries and using positions `"extra2"`, `"extra3"`, …

## Test

```sh
luajit ~/.config/yazi/plugins/yatline-extra.yazi/test/stub-test.lua
```

Runtime smoke-test with stubbed yazi API: exercises setup, config merge,
`Root.layout`/`Root.build`, `ExtraLine:redraw()` paths, the
DiskTabs resolver (mounts parse / longest-prefix / labels / prefixes)
and the disk-bar/dir-size/sel-size components (incl. anti-jitter: pending
coalescing, caching, stale-drop, argless entry) without a terminal.

Upstream README: see git history / [imsi32/yatline](https://github.com/imsi32/yatline).
