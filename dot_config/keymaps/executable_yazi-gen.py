#!/usr/bin/env python3
"""Generate Russian-layout twin keybindings for yazi.

Reads ~/.config/yazi/keymap.toml, finds every entry whose `on` consists
solely of single ASCII chars present in the prometeus→ru mapping, and
creates a duplicate entry with the russian equivalents.

Modes:
  --check         (default) write the augmented keymap to <out>; keymap.toml untouched
  --apply         overwrite keymap.toml in place (a .bak is kept first time only)

Files:
  mapping  ~/.config/keymaps/prometeus-ru.json
  source   ~/.config/yazi/keymap.toml
  out      ~/.config/yazi/keymap.ru.preview.toml  (only in --check mode)
"""
from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

import tomlkit
from tomlkit.items import Array, InlineTable, Table, AoT


MAP_PATH = Path("~/.config/keymaps/prometeus-ru.json").expanduser()
SRC_PATH = Path("~/.config/yazi/keymap.toml").expanduser()
OUT_PATH = Path("~/.config/yazi/keymap.ru.preview.toml").expanduser()

KEYMAP_ARRAYS = ("keymap", "prepend_keymap", "append_keymap")


def load_mapping() -> dict[str, str]:
    data = json.loads(MAP_PATH.read_text())
    return {**data["map"], **data["shift_map"]}


def translate_keys(keys, xlate) -> list[str] | None:
    out = []
    for k in keys:
        if not isinstance(k, str) or len(k) != 1 or k not in xlate:
            return None
        out.append(xlate[k])
    return out


def clone_entry(entry, ru_keys):
    """Make a copy of `entry` with `on` replaced by ru_keys."""
    new = tomlkit.inline_table()
    new["on"] = ru_keys[0] if len(ru_keys) == 1 else ru_keys
    for k, v in entry.items():
        if k == "on":
            continue
        new[k] = v
    return new


def process_array(arr: Array, xlate) -> list:
    new_items = []
    for item in arr:
        if not isinstance(item, (InlineTable, dict)):
            continue
        on = item.get("on")
        if on is None:
            continue
        keys = on if isinstance(on, list) else [on]
        ru = translate_keys(keys, xlate)
        if ru is None:
            continue
        new_items.append(clone_entry(item, ru))
    return new_items


def walk(node, xlate, added_counter):
    """Recursively walk TOML tables and augment any keymap arrays."""
    if isinstance(node, (Table, dict)):
        for key in list(node.keys()):
            val = node[key]
            if key in KEYMAP_ARRAYS and isinstance(val, Array):
                twins = process_array(val, xlate)
                for t in twins:
                    val.append(t)
                added_counter[0] += len(twins)
            elif isinstance(val, (Table, dict)):
                walk(val, xlate, added_counter)
            elif isinstance(val, AoT):
                # array of tables: each [[section.prepend_keymap]] entry
                # Collect those that look like keymap entries and add twins
                new_entries = []
                for sub in val:
                    on = sub.get("on")
                    if on is None:
                        # nested table — recurse
                        walk(sub, xlate, added_counter)
                        continue
                    keys = on if isinstance(on, list) else [on]
                    ru = translate_keys(keys, xlate)
                    if ru is None:
                        continue
                    twin = tomlkit.table()
                    twin["on"] = ru[0] if len(ru) == 1 else ru
                    for k, v in sub.items():
                        if k == "on":
                            continue
                        twin[k] = v
                    new_entries.append(twin)
                for e in new_entries:
                    val.append(e)
                added_counter[0] += len(new_entries)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true",
                    help="overwrite keymap.toml in place (creates .bak once)")
    ap.add_argument("--src", default=str(SRC_PATH))
    ap.add_argument("--out", default=str(OUT_PATH))
    args = ap.parse_args()

    src = Path(args.src).expanduser()
    out = Path(args.out).expanduser()

    xlate = load_mapping()
    doc = tomlkit.parse(src.read_text())

    counter = [0]
    walk(doc, xlate, counter)

    target = src if args.apply else out
    if args.apply:
        bak = src.with_suffix(src.suffix + ".pre-ru.bak")
        if not bak.exists():
            shutil.copy2(src, bak)
            print(f"✔ backup: {bak}")
    target.write_text(tomlkit.dumps(doc))
    print(f"✔ wrote {target}")
    print(f"  added {counter[0]} russian twin entries")
    return 0


if __name__ == "__main__":
    sys.exit(main())
