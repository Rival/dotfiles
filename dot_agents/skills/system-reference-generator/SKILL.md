---
name: system-reference-generator
description: Use when scanning system, creating system reference, or generating system docs. Scans OS, hardware, disks, software, dev tools, displays, audio, services, network, dotfiles, and Knowledge Zones from .folder-reference dirs. Creates ~/.claude/skills/system-reference/ with compact SKILL.md and detailed references. Use --zone-add to add knowledge zones interactively.
---

# System Reference Generator

Scan the current machine and generate `~/.claude/skills/system-reference/` — a personal system passport for Claude. Two-level loading: compact SKILL.md always in context, detailed references loaded on demand.

## Output Structure

```
~/.claude/skills/system-reference/
├── SKILL.md                          # Compact summary (~60 lines, always in context)
├── references/
│   ├── os-environment.md             # OS, kernel, shell, DE, locale, timezone, hardware
│   ├── installed-software.md         # All key software by category with versions
│   ├── storage-map.md                # Disks, partitions, mounts, top-level dirs
│   ├── displays-audio.md             # Monitors, resolution, audio devices
│   ├── dev-environment.md            # Languages, SDKs, IDEs, toolchains, env vars
│   ├── services-network.md           # Running services, ports, SSH keys, VPN
│   └── dotfiles-config.md            # Shell rc, aliases, PATH, key configs
└── scripts/
    └── scan_system.py                # Rescan script
```

## How to Generate

**Step 1:** Run the scanner script to collect raw system data:

```bash
python3 ~/.claude/skills/system-reference-generator/scripts/scan_system.py
```

This creates `~/.claude/skills/system-reference/` with all files populated.

**Step 2:** Review generated SKILL.md, optionally edit to add personal notes.

**Step 3 (optional):** Create `.folder-reference/README.md` in important directories. Rescan to update the registry.

## Updating

```bash
# Full rescan
python3 ~/.claude/skills/system-reference-generator/scripts/scan_system.py

# Rescan specific section
python3 ~/.claude/skills/system-reference-generator/scripts/scan_system.py --section storage
python3 ~/.claude/skills/system-reference-generator/scripts/scan_system.py --section software
python3 ~/.claude/skills/system-reference-generator/scripts/scan_system.py --section displays
```

## Knowledge Zones

Knowledge Zones connect **domains** (areas of knowledge) to **storage paths**. When Claude asks about a domain, it loads the relevant reference.

```
/home/user/Games/Emulation/
├── .folder-reference/
│   ├── meta.yaml       # Domain metadata
│   └── README.md       # Detailed reference
├── ROMs/
└── Configs/
```

**meta.yaml format:**
```yaml
domain: emulation          # Domain name (empty = storage-only)
type: domain+storage       # domain / storage / domain+storage
load_rule: always          # always / on-query / never
description: Эмуляторы, ROMs, конфиги
```

**Types:**
- **domain** (🏠) — knowledge area only, always load `.folder-reference/README.md` before answering
- **storage** (📁) — files only, can answer with `ls`/`find` without loading reference
- **domain+storage** — both knowledge and files

**Load rules:**
- **always** — load for ALL questions about this domain
- **on-query** — only when listing/searching files
- **never** — context only

**Adding zones interactively:**
```bash
python3 ~/.claude/skills/system-reference-generator/scripts/scan_system.py --zone-add /path/to/folder
```

**After adding zones, rescan folders section:**
```bash
python3 ~/.claude/skills/system-reference-generator/scripts/scan_system.py --section folders
```

This updates `storage-map.md` with the Knowledge Zones table.

## /sys-ask Command

The `/sys-ask` command (slash command) queries system knowledge:

```
/sys-ask какие игры у меня есть для сеги?
/sys-ask где лежат конфиги эмуляторов?
/sys-ask покажи storage map
```

**How it works:**
1. Always loads `storage-map.md` (contains Knowledge Zones table)
2. Searches for matching domain/path
3. If domain found with `load_rule: always` — loads `.folder-reference/README.md`
4. Returns answer with reference to relevant paths

**Example flow:**
```
User: /sys-ask какие игры есть для сеги?

Claude:
1. Loads storage-map.md
2. Finds domain "sega" → `/mnt/Games/Sega` (storage, on-query)
3. Runs: ls /mnt/Games/Sega
4. Returns: "Found Sega games at /mnt/Games/Sega:
   - Sonic.exe
   - Streets of Rage 2.iso
   ..."
```

## Cross-Platform Support

| Module | Linux | macOS | Windows |
|--------|-------|-------|---------|
| OS info | `uname`, `/etc/os-release` | `sw_vers`, `uname` | `systeminfo`, `wmic` |
| Hardware | `lscpu`, `free`, `lspci` | `system_profiler`, `sysctl` | `wmic`, PowerShell |
| Storage | `lsblk`, `df`, `mount` | `diskutil`, `df` | `Get-Volume`, `wmic` |
| Software | `pacman`/`apt`/`dnf`, `snap`, `flatpak` | `brew`, `mas` | `winget`, `choco` |
| Displays | `xrandr`, `kscreen-doctor`, `wlr-randr` | `system_profiler SPDisplaysDataType` | PowerShell |
| Audio | `pactl`, `wpctl` | `system_profiler SPAudioDataType` | PowerShell |
| Services | `systemctl` | `launchctl` | `Get-Service` |
| Network | `ip`, `ss` | `ifconfig`, `lsof` | `netstat`, `ipconfig` |
| Dev tools | `which`/`command -v` | same | `where`, `Get-Command` |
| Dotfiles | `~/.bashrc`, `~/.zshrc` | same | `$PROFILE` |

## SKILL.md Template (generated output)

See [system-reference-template.md](references/system-reference-template.md) for the output SKILL.md format.

## Reference Templates

See [reference-templates.md](references/reference-templates.md) for detailed reference file formats.
