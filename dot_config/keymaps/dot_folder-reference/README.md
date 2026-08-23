# Keymaps Zone

Centralized physical-key mapping between the **English (Prometeus)** custom
xkb layout and the standard **Russian (ЙЦУКЕН)** layout, plus per-application
generators that emit "twin" keybindings so TUI tools work in both layouts.

## Why this exists

Most TUI apps (yazi, kitty, helix, lazygit, …) read **decoded Unicode chars**
from the terminal — they don't see physical keycodes. So when the user
switches to ru, `q` becomes `й` and previously-bound keys stop matching.
Apps need an explicit duplicate binding for the russian char that lives on
the same physical key position.

This zone is the single source of truth for that mapping and the place where
all per-app generators live.

## Files

```
~/.config/keymaps/
├── prometeus-ru.json   # the mapping (physical position → ru char)
├── yazi-gen.py         # generator for yazi keymap.toml
└── kitty-gen.py        # generator for kitty *.conf
```

### `prometeus-ru.json`

JSON with two tables (`map` for base layer, `shift_map` for shifted layer).
Each entry maps an EN char to the RU char that sits on the same physical
xkb position (AD01..AB10). Numbers 0–9 are omitted (same position in both
layouts). `LSGT` (prometeus `r`) has no ru equivalent — skipped.

Source of truth for the prometeus layout itself:
`/usr/share/X11/xkb/symbols/prometeus`.

### `yazi-gen.py`

Reads `~/.config/yazi/keymap.toml` via **tomlkit** (preserves comments &
inline formatting), walks every `keymap` / `prepend_keymap` /
`append_keymap` array (across all sections — `mgr`, `tasks`, `pick`,
`select`, `input`, …), and for each entry whose `on` is fully mappable
inserts a twin entry with russian keys directly into the same array.

- `python3 yazi-gen.py` → preview at `~/.config/yazi/keymap.ru.preview.toml`
- `python3 yazi-gen.py --apply` → in-place edit; backup at
  `~/.config/yazi/keymap.toml.pre-ru.bak`

### `kitty-gen.py`

Reads `~/.config/kitty/kitty.conf` and `prometeum.conf`, parses every
`map <combo> <action>` (including chord syntax `kitty_mod+l>f`), and emits
russian twins into a separate file that's loaded via `include`.

- `python3 kitty-gen.py` → writes `~/.config/kitty/kitty-ru.generated.conf`
- `python3 kitty-gen.py --apply` → same, plus appends
  `include kitty-ru.generated.conf` to `kitty.conf` (idempotent)

`collect_existing()` deduplicates: combos already bound in the sources are
not regenerated — manual bindings always win.

## Applications & status

| App         | Approach                                   | Status          |
|-------------|--------------------------------------------|-----------------|
| yazi        | tomlkit in-place merge, twins in arrays    | ✅ applied      |
| kitty       | separate `kitty-ru.generated.conf` + `include` | ✅ applied  |
| lazygit     | only `customCommands[].key` duplicatable; built-in keybindings are 1:1 action→key so dual-binding is not possible nativly | ❌ not viable in-app |
| hyprland    | already multilingual via `kb_layout = prometeus, ru` — no app-level work needed | n/a |

### Why not a system-wide fix?

A Hyprland windowrule that force-switches a window to EN when focused
(`hyprctl switchxkblayout`) would make all TUIs work without per-app
generators, but:

- Breaks intentional cyrillic input inside the same window (e.g. typing
  search queries in russian).
- Fights with the user's manual `Alt+Shift` toggle.

The per-app generator approach is more surgical: bindings work in both
layouts, typing still respects the active layout.

## Adding a new app

1. Confirm the app reads single-char keys (most TUIs do).
2. Identify its config format (TOML / YAML / plain text / Lua / …).
3. Write `<app>-gen.py` next to the existing generators:
   - read `prometeus-ru.json`
   - parse the app's bindings
   - emit twins where every key in the combo is in the mapping
   - skip combos that are *already* bound (manual entries win)
4. Decide merge strategy:
   - **In-place edit** (yazi-style) — when the config can be parsed/written
     by a round-trip library that preserves formatting.
   - **Separate include file** (kitty-style) — when the app supports an
     `include`/`source` directive.
   - **Snippet output** — fallback when neither is possible; user pastes
     manually.

## Mapping reference (physical → ru)

```
Top:    v p d l x | / , . ; z
        й ц у к е | н г ш щ з

Home:   s n t h k | q e a i c
        ф ы в а п | р о л д ж

Bottom: f w g m j | - u o y b
        я ч с м и | т ь б ю .
```

Shifted forms in `shift_map` (`?→Н`, `<→Г`, `_→Т`, `B→,` etc.) are not
derivable from `.upper()` and must be looked up explicitly.

## Constraints & gotchas

- Bindings on `<C-x>`, `<Esc>`, `<F1>`, digits — layout-independent,
  generators skip them on purpose.
- Prometeus's `LSGT` key (`r`/`R`) has no ru twin — also skipped.
- For yazi `[pick]` section the user uses `keymap = [...]` (full override);
  twins still go into the same array, so they're prepended in effect.
- After regenerating, **reload** the app: yazi restart, kitty `ctrl+shift+f5`
  or new window.
