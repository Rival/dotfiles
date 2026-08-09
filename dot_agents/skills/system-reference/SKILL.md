---
name: cachy-system-reference
description: System environment reference for CachyOS Desktop (andreiryzen). Contains OS, hardware, installed software, storage map, audio, emulation setup, and network info. Load when working with system tasks on CachyOS, SSH operations, file transfers, emulation setup, or when context about Andrey's Linux desktop is needed.
---

# CachyOS Desktop — System Reference

> **Host:** andreiryzen · **Tailscale:** `100.100.41.75` · **SSH:** `andrei@100.100.41.75`
> **Last scanned:** 2026-07-05

## System

| Param | Value |
|-------|-------|
| Hostname | andreiryzen |
| OS | CachyOS (Arch-based, rolling) |
| Kernel | 7.1.2-3-cachyos |
| Shell | fish 4.7.1 (use `bash -lc` for scripts) |
| DE/WM | Hyprland 0.55.4 (Wayland) |
| Bar/Panel | quickshell 0.3.0 |
| CPU | AMD Ryzen 9 5950X (16c/32t, 3.4GHz base) |
| RAM | 62 GiB |
| GPU | NVIDIA RTX 3080 LHR (10GB GDDR6X) |
| GPU Driver | 610.43.02 (proprietary) |
| Audio | PipeWire 1.6.7 + WirePlumber 1.6.7 |

## Network

| Interface | IP | Note |
|-----------|-----|------|
| wlan0 | 192.168.1.45/24 | LAN |
| tailscale0 | 100.100.41.75/32 | Tailscale (`andreiryzen`) |

**Tailscale peers:**
- `100.99.99.83` — andreys-mac-mini (Regina)
- `100.68.51.19` — andreys-mac-mini-2 (РобоАндрей)

## Storage

| Mount | Device | Size | Used | % | Type |
|-------|--------|------|------|---|------|
| `/` (root) | nvme1n1p5 | 1001G | 808G | 82% | btrfs |
| `/home` | nvme1n1p5 | 1001G | 808G | 82% | btrfs |
| `/mnt/Crucial4TB` | nvme0n1p2 | 3.7T | 2.6T | 71% | ntfs |
| `/mnt/Windows` | nvme1n1p2 | 1.9T | 1.1T | 55% | ntfs |
| `/mnt/mint` | nvme1n1p4 | 531G | 347G | 69% | ext4 |
| `/mnt/Downloads2TB` | sda1 | 1.9T | 1.7T | 94% | ntfs |
| `/mnt/WD1TB` | sdc1 | 916G | 369G | 43% | ntfs |
| `/mnt/Patriot512GB` | sdb2 | 477G | 214G | 45% | ntfs |
| `/mnt/Games` | sda2 | — | — | — | — |
| `/mnt/Drive4TB` | — | — | — | — | — |
| `/mnt/Intel2TB` | — | — | — | — | — |
| `/mnt/data` | — | — | — | — | — |
| `/mnt/fingerssd` | — | — | — | — | — |
| zram0 | — | 62.7G | — | — | zram |

**Physical disks:**
- `nvme0n1` — Crucial CT4000P3PSSD8 (4TB NVMe)
- `nvme1n1` — Samsung 990 EVO Plus (4TB NVMe) — boot drive
- `sda` — Samsung 870 QVO (2TB SATA SSD)
- `sdb` — Patriot P210 (512GB SATA SSD)
- `sdc` — WDC WDS100T2B0C (1TB SATA SSD)

## Key Software

| Category | Tools |
|----------|-------|
| Package Mgrs | pacman, yay 13.0.1, flatpak 1.18.0, npm 11.16, cargo 1.96, pip |
| Languages | python 3.14.6, node 22.23.1, go 1.26.4, rust 1.96.1, java 21.0.11, gcc 16.1.1, clang 22.1.6 |
| Dev Tools | git 2.55.0, make 4.4.1, cmake 4.3.4, nvim 0.12.3, tmux 3.7b, jq 1.8.2, rsync 3.4.4, sqlite3 3.53.3 |
| Browsers | firefox 152.0.4, google-chrome-stable |
| Media | mpv 0.41.0, vlc 3.0.23, obs 32.1.2, gimp 3.2.4 |
| Comms | telegram-desktop, zoom 7.1.0 |
| AI/LLM | Claude Code 2.1.201 |
| System | btop 1.4.7, curl 8.x, wget |

## Audio

| Device | Type | Default |
|--------|------|---------|
| GA102 HDMI Digital Stereo | Output | ✅ Default |
| GSX 1000 Analog Surround 7.1 | Output | — |
| GSX 1000 Chat | Output | — |
| EMEET SmartCam C960 2K Analog Stereo | Input | — |
| GSX 1000 Chat Input | Input | ✅ Default |

## Emulation

| Emulator | Version | Keys | ROMs |
|----------|---------|------|------|
| **Eden** | 0.2.1-3 (pacman) | `~/.local/share/eden/keys/` (prod.keys 14k, title.keys 11k) | NAND initialized |
| **Citron** | 2026.02.1-2 | `~/.local/share/citron/keys/` (prod.keys, title.keys) | — |
| **Cemu** | installed | — | — |

**Eden config:** `~/.config/eden/` (qt-config.ini, gui_config.ini)
**Eden data:** `~/.local/share/eden/` (nand, sdmc, amiibo, screenshots, shader, save data)

**ROM library:** `/mnt/WD1TB/emudeck/Switch/`
- Super Smash Bros Ultimate [NSZ] (3.66 GB) + 99 DLCs

**Torrents (not downloaded):**
- Super Mario Odyssey [NSZ] — `~/Downloads/`
- Super Mario Galaxy 1+2 [NSP] — `~/Downloads/`
- Super Mario RPG [NSZ] — `~/Downloads/`
- Zelda BOTW [NSZ] — `~/Downloads/`
- Zelda TOTK [NSP] — `~/Downloads/`
- Pikmin 4 [NSP] — `~/Downloads/`
- Captain Toad [NSZ] — `~/Downloads/`

## Known Issues

| Issue | Impact | Status |
|-------|--------|--------|
| GTK4 Wayland apps hang (wayland regression) | GTK4 apps freeze on startup | Workaround: `GDK_BACKEND=x11` |
| NVIDIA GSP heartbeat timeouts (RTX 3080) | HDMI-A-2 freezes every 3-5h | Fixed: `NVreg_EnableGpuFirmware=0` |
| HDR washed-out after cold boot | Pale 4K HDR colors | Workaround: `systemctl suspend` + wake |
| Pacman "marginal/unknown trust" sig errors | install/sync fails | Fix: `pacman -Sy archlinux-keyring` |
| Root partition 82% full | — | Monitor, 190G free |

## SSH Access

```bash
# From Regina (macmini) or any Tailscale peer:
ssh andrei@100.100.41.75

# fish is default shell — for bash scripts prefix with:
ssh andrei@100.100.41.75 'bash -lc "..."

# Kitty remote control is available:
# Socket: /tmp/mykitty (persistent, allow_remote_control=yes)
```

## Quick Reference Paths

| What | Path |
|------|------|
| Home | `/home/andrei` |
| Downloads | `/home/andrei/Downloads` |
| Eden keys | `~/.local/share/eden/keys/` |
| Citron keys | `~/.local/share/citron/keys/` |
| Eden config | `~/.config/eden/` |
| ROM library | `/mnt/WD1TB/emudeck/Switch/` |
| Claude skills | `~/.claude/skills/` |
| Kitty socket | `/tmp/mykitty` |
