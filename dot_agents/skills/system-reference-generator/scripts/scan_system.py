#!/usr/bin/env python3
"""
System Reference Scanner

Scans the current machine and generates ~/.claude/skills/system-reference/
with SKILL.md (compact summary) and references/*.md (detailed info).

Usage:
    python3 scan_system.py                    # Full scan
    python3 scan_system.py --section storage  # Rescan specific section
    python3 scan_system.py --output /path     # Custom output dir
"""

import argparse
import os
import platform
import re
import shutil
import subprocess
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def run(cmd: str, timeout: int = 10) -> str:
    """Run shell command, return stdout or empty string on failure."""
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
        return r.stdout.strip() if r.returncode == 0 else ""
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
        return ""


def which(name: str) -> str:
    """Check if command exists, return path or empty."""
    return shutil.which(name) or ""


def get_version(cmd: str) -> str:
    """Try common version flags."""
    for flag in ["--version", "-version", "-V", "version"]:
        out = run(f"{cmd} {flag} 2>/dev/null")
        if out:
            # Take first line, strip common prefixes
            line = out.split("\n")[0].strip()
            # Extract version number if possible
            m = re.search(r"(\d+\.\d+[\.\d]*)", line)
            return m.group(1) if m else line[:80]
    return ""


def detect_os() -> str:
    """Detect OS type: linux, darwin, windows."""
    return platform.system().lower()


OS = detect_os()


# ---------------------------------------------------------------------------
# Scanners — each returns a dict with 'summary' (for SKILL.md) and 'detail' (for references/)
# ---------------------------------------------------------------------------

def scan_os_info() -> Dict:
    """Scan OS, kernel, shell, DE, locale, timezone, hardware."""
    info = {}

    # Basic OS
    info["hostname"] = platform.node()
    info["arch"] = platform.machine()
    info["kernel"] = platform.release()

    if OS == "linux":
        # Distro
        os_release = run("cat /etc/os-release 2>/dev/null")
        info["os_name"] = ""
        info["os_version"] = ""
        for line in os_release.split("\n"):
            if line.startswith("PRETTY_NAME="):
                info["os_name"] = line.split("=", 1)[1].strip('"')
            elif line.startswith("VERSION_ID="):
                info["os_version"] = line.split("=", 1)[1].strip('"')
        if not info["os_name"]:
            info["os_name"] = run("uname -o") or "Linux"

        # DE/WM
        info["de"] = os.environ.get("XDG_CURRENT_DESKTOP", "") or os.environ.get("DESKTOP_SESSION", "")
        info["display_server"] = "Wayland" if os.environ.get("WAYLAND_DISPLAY") else "X11"
        info["session_type"] = os.environ.get("XDG_SESSION_TYPE", "")

    elif OS == "darwin":
        info["os_name"] = f"macOS {run('sw_vers -productVersion')}"
        info["os_version"] = run("sw_vers -buildVersion")
        info["de"] = "Aqua"
        info["display_server"] = "Quartz"

    elif OS == "windows":
        info["os_name"] = f"Windows {platform.version()}"
        info["os_version"] = platform.version()
        info["de"] = "Explorer"
        info["display_server"] = "DWM"

    # Shell
    info["shell"] = os.environ.get("SHELL", "").split("/")[-1] or "unknown"
    info["shell_version"] = run(f"{info['shell']} --version 2>/dev/null").split("\n")[0][:60] if info["shell"] != "unknown" else ""

    # Locale / timezone
    info["lang"] = os.environ.get("LANG", "")
    info["timezone"] = run("timedatectl show -p Timezone --value 2>/dev/null") or run("cat /etc/timezone 2>/dev/null") or ""

    # CPU
    if OS == "linux":
        lscpu = run("lscpu")
        info["cpu_model"] = ""
        info["cpu_cores"] = ""
        info["cpu_threads"] = ""
        for line in lscpu.split("\n"):
            if "Model name:" in line:
                info["cpu_model"] = line.split(":", 1)[1].strip()
            elif "Core(s) per socket:" in line:
                info["cpu_cores"] = line.split(":", 1)[1].strip()
            elif "CPU(s):" in line and not info["cpu_threads"]:
                info["cpu_threads"] = line.split(":", 1)[1].strip()
    elif OS == "darwin":
        info["cpu_model"] = run("sysctl -n machdep.cpu.brand_string")
        info["cpu_cores"] = run("sysctl -n hw.physicalcpu")
        info["cpu_threads"] = run("sysctl -n hw.logicalcpu")
    else:
        info["cpu_model"] = platform.processor() or "unknown"
        info["cpu_cores"] = ""
        info["cpu_threads"] = str(os.cpu_count() or "")

    # RAM
    if OS == "linux":
        meminfo = run("free -h --si")
        mem_line = [l for l in meminfo.split("\n") if l.startswith("Mem:")]
        if mem_line:
            parts = mem_line[0].split()
            info["ram_total"] = parts[1] if len(parts) > 1 else ""
            info["ram_used"] = parts[2] if len(parts) > 2 else ""
            info["ram_avail"] = parts[6] if len(parts) > 6 else ""
        swap_line = [l for l in meminfo.split("\n") if l.startswith("Swap:")]
        if swap_line:
            parts = swap_line[0].split()
            info["swap_total"] = parts[1] if len(parts) > 1 else "0"
            info["swap_used"] = parts[2] if len(parts) > 2 else "0"
    elif OS == "darwin":
        mem_bytes = run("sysctl -n hw.memsize")
        info["ram_total"] = f"{int(mem_bytes) // (1024**3)} GB" if mem_bytes.isdigit() else ""
    else:
        info["ram_total"] = ""

    # GPU
    info["gpus"] = []
    if OS == "linux":
        lspci = run("lspci 2>/dev/null")
        for line in lspci.split("\n"):
            if "VGA" in line or "3D" in line or "Display" in line:
                info["gpus"].append(line.split(": ", 1)[-1] if ": " in line else line)
        # NVIDIA driver
        nvidia_smi = run("nvidia-smi --query-gpu=driver_version,memory.total --format=csv,noheader,nounits 2>/dev/null")
        if nvidia_smi:
            info["nvidia_driver"] = nvidia_smi.split(",")[0].strip()
            info["nvidia_vram"] = nvidia_smi.split(",")[1].strip() + " MiB" if "," in nvidia_smi else ""
    elif OS == "darwin":
        gpu = run("system_profiler SPDisplaysDataType 2>/dev/null | grep 'Chipset Model'")
        if gpu:
            info["gpus"].append(gpu.split(":", 1)[-1].strip())

    return info


def scan_storage() -> Dict:
    """Scan disks, partitions, mount points, key directories."""
    info = {"disks": [], "mounts": [], "key_dirs": {}}

    if OS == "linux":
        # Disks
        lsblk = run("lsblk -d -o NAME,SIZE,TYPE,MODEL,ROTA -n 2>/dev/null")
        for line in lsblk.split("\n"):
            if not line.strip():
                continue
            parts = line.split(None, 4)
            if len(parts) >= 3:
                disk_type = "HDD" if (len(parts) > 4 and parts[4].strip() == "1") else "SSD/NVMe"
                info["disks"].append({
                    "name": parts[0], "size": parts[1],
                    "type": disk_type,
                    "model": parts[3] if len(parts) > 3 else ""
                })

        # Mount points — use findmnt for clean output, deduplicate by device
        findmnt_out = run("findmnt -rn -o SOURCE,SIZE,USED,AVAIL,USE%,TARGET,FSTYPE -t nosysfs,noproc,notmpfs,nodevtmpfs,nosquashfs,noautofs,nocgroup2,nofuse.portal 2>/dev/null")
        if not findmnt_out:
            # Fallback to df
            findmnt_out = ""
            df_out = run("df -h --output=source,size,used,avail,pcent,target -x tmpfs -x devtmpfs -x squashfs 2>/dev/null")
            for line in df_out.split("\n")[1:]:
                parts = line.split(None, 5)
                if len(parts) >= 6 and not parts[0].startswith("tmpfs"):
                    fstype = run(f"findmnt -n -o FSTYPE {parts[5]} 2>/dev/null") or ""
                    info["mounts"].append({
                        "device": parts[0], "size": parts[1], "used": parts[2],
                        "avail": parts[3], "use_pct": parts[4], "mount": parts[5],
                        "fstype": fstype
                    })

        # Parse findmnt and deduplicate: for same device, keep only shortest mount path (main mount)
        seen_devices = {}
        for line in findmnt_out.split("\n"):
            parts = line.split(None, 6)
            if len(parts) >= 7:
                device, size, used, avail, use_pct, mount, fstype = parts[0], parts[1], parts[2], parts[3], parts[4], parts[5], parts[6]
                # Skip efivarfs, btrfs subvolumes that are just submounts
                if fstype == "efivarfs":
                    continue
                # For btrfs: keep / and /home and unique real mounts, skip subvol duplicates
                if device in seen_devices:
                    prev_mount = seen_devices[device]["mount"]
                    # Keep /home over /, keep shorter meaningful paths, skip /var/cache etc.
                    if mount in ("/", "/home") and prev_mount not in ("/", "/home"):
                        seen_devices[device] = {"device": device, "size": size, "used": used, "avail": avail, "use_pct": use_pct, "mount": mount, "fstype": fstype}
                    elif mount == "/home":
                        # Always add /home separately
                        info["mounts"].append({"device": device, "size": size, "used": used, "avail": avail, "use_pct": use_pct, "mount": mount, "fstype": fstype})
                    # Skip other subvolumes of same device
                    continue
                seen_devices[device] = {"device": device, "size": size, "used": used, "avail": avail, "use_pct": use_pct, "mount": mount, "fstype": fstype}

        # Add deduplicated mounts (filter out system mounts)
        # Keep only: /, /home, /mnt/*, /srv, /media/* (user-relevant mounts)
        SYSTEM_PREFIXES = ("/sys", "/proc", "/dev", "/run", "/boot", "/var", "/tmp", "/snap")
        for m in seen_devices.values():
            mount = m["mount"]
            # Skip system mounts
            if mount.startswith(SYSTEM_PREFIXES):
                continue
            # Skip efivarfs
            if m.get("fstype") == "efivarfs":
                continue
            # Skip non-mounted /boot/efi unless vfat
            if mount == "/boot/efi" and m.get("fstype") != "vfat":
                continue
            info["mounts"].append(m)

        # Key dirs per mount (only for user-relevant mounts)
        USER_MOUNTS = ("/", "/home")
        MOUNT_PREFIXES = ("/mnt/", "/media/")
        for m in info["mounts"]:
            mount = m["mount"]
            if mount == "/":
                # Scan home dirs only
                home = Path.home()
                dirs = []
                try:
                    for d in sorted(home.iterdir()):
                        if d.is_dir() and not d.name.startswith("."):
                            dirs.append(d.name)
                except PermissionError:
                    pass
                info["key_dirs"][str(home)] = dirs[:20]
            elif mount in USER_MOUNTS or mount.startswith(MOUNT_PREFIXES):
                # Scan user-relevant mounts
                try:
                    dirs = [d.name for d in sorted(Path(mount).iterdir()) if d.is_dir() and not d.name.startswith(".")]
                    if dirs:  # Only add if there are directories
                        info["key_dirs"][mount] = dirs[:30]
                except (PermissionError, OSError):
                    pass

    elif OS == "darwin":
        df_out = run("df -h")
        for line in df_out.split("\n")[1:]:
            parts = line.split(None, 8)
            if len(parts) >= 9 and parts[0].startswith("/dev"):
                info["mounts"].append({
                    "device": parts[0], "size": parts[1], "used": parts[2],
                    "avail": parts[3], "use_pct": parts[4], "mount": parts[8],
                    "fstype": ""
                })

    return info


def scan_displays() -> Dict:
    """Scan connected displays."""
    info = {"displays": []}

    if OS == "linux":
        # Try xrandr first
        xrandr = run("xrandr --current 2>/dev/null")
        if xrandr:
            current_display = None
            for line in xrandr.split("\n"):
                if " connected" in line:
                    parts = line.split()
                    name = parts[0]
                    primary = "primary" in line
                    # Find resolution in the line
                    res_match = re.search(r"(\d+x\d+)\+(\d+)\+(\d+)", line)
                    current_display = {
                        "name": name, "primary": primary,
                        "resolution": res_match.group(1) if res_match else "",
                        "position": f"{res_match.group(2)},{res_match.group(3)}" if res_match else "",
                        "refresh": "", "connection": ""
                    }
                    info["displays"].append(current_display)
                elif current_display and "*" in line:
                    # Active mode line
                    hz_match = re.search(r"([\d.]+)\*", line)
                    if hz_match:
                        current_display["refresh"] = hz_match.group(1)
                    current_display = None

        # Try kscreen-doctor for KDE
        if not info["displays"]:
            kscreen = run("kscreen-doctor -o 2>/dev/null")
            # Parse kscreen output if available
            if kscreen:
                for line in kscreen.split("\n"):
                    if "Output" in line and "enabled" in line:
                        name_match = re.search(r"Output \d+: (\S+)", line)
                        if name_match:
                            info["displays"].append({"name": name_match.group(1), "resolution": "", "refresh": "", "primary": False, "position": "", "connection": ""})

        # Try wlr-randr for wlroots
        if not info["displays"]:
            wlr = run("wlr-randr 2>/dev/null")
            if wlr:
                for line in wlr.split("\n"):
                    if not line.startswith(" ") and line.strip():
                        name = line.split()[0]
                        info["displays"].append({"name": name, "resolution": "", "refresh": "", "primary": False, "position": "", "connection": ""})

    elif OS == "darwin":
        sp = run("system_profiler SPDisplaysDataType 2>/dev/null")
        # Simple parse
        for block in sp.split("Display Type:"):
            res_match = re.search(r"Resolution:\s*(.+)", block)
            name_match = re.search(r"Display Type:\s*(.+)", block)
            if res_match:
                info["displays"].append({
                    "name": name_match.group(1).strip() if name_match else "Display",
                    "resolution": res_match.group(1).strip(),
                    "refresh": "", "primary": False, "position": "", "connection": ""
                })

    return info


def scan_audio() -> Dict:
    """Scan audio devices."""
    info = {"sinks": [], "sources": []}

    if OS == "linux":
        # Try pactl (PulseAudio/PipeWire)
        sinks = run("pactl list sinks short 2>/dev/null")
        for line in sinks.split("\n"):
            if not line.strip():
                continue
            parts = line.split("\t")
            if len(parts) >= 2:
                info["sinks"].append({"name": parts[1], "state": parts[-1] if len(parts) > 2 else ""})

        sources = run("pactl list sources short 2>/dev/null")
        for line in sources.split("\n"):
            if not line.strip():
                continue
            parts = line.split("\t")
            if len(parts) >= 2 and "monitor" not in parts[1].lower():
                info["sources"].append({"name": parts[1], "state": parts[-1] if len(parts) > 2 else ""})

        # Get default sink/source
        info["default_sink"] = run("pactl get-default-sink 2>/dev/null")
        info["default_source"] = run("pactl get-default-source 2>/dev/null")

        # Try to get friendly names
        sink_details = run("pactl list sinks 2>/dev/null")
        name_map = {}
        current_name = ""
        for line in sink_details.split("\n"):
            if "Name:" in line:
                current_name = line.split(":", 1)[1].strip()
            elif "Description:" in line and current_name:
                name_map[current_name] = line.split(":", 1)[1].strip()
                current_name = ""
        info["sink_names"] = name_map

        source_details = run("pactl list sources 2>/dev/null")
        source_map = {}
        current_name = ""
        for line in source_details.split("\n"):
            if "Name:" in line:
                current_name = line.split(":", 1)[1].strip()
            elif "Description:" in line and current_name:
                source_map[current_name] = line.split(":", 1)[1].strip()
                current_name = ""
        info["source_names"] = source_map

    elif OS == "darwin":
        sp = run("system_profiler SPAudioDataType 2>/dev/null")
        # Simple extraction
        for line in sp.split("\n"):
            line = line.strip()
            if ":" in line and not line.startswith("Audio"):
                key, val = line.split(":", 1)
                if "Output" in key:
                    info["sinks"].append({"name": val.strip(), "state": ""})
                elif "Input" in key:
                    info["sources"].append({"name": val.strip(), "state": ""})

    return info


def scan_software() -> Dict:
    """Scan installed software by category."""
    info = {"pkg_managers": [], "categories": {}}

    # Detect package managers
    pkg_mgrs = [
        ("pacman", "pacman -Q | wc -l"),
        ("yay", "yay -Q | wc -l"),
        ("apt", "dpkg -l | grep ^ii | wc -l"),
        ("dnf", "dnf list installed 2>/dev/null | wc -l"),
        ("brew", "brew list | wc -l"),
        ("snap", "snap list 2>/dev/null | tail -n +2 | wc -l"),
        ("flatpak", "flatpak list 2>/dev/null | wc -l"),
        ("npm", "npm -g list --depth=0 2>/dev/null | tail -n +2 | wc -l"),
        ("pip", "pip list 2>/dev/null | tail -n +3 | wc -l"),
        ("cargo", "cargo install --list 2>/dev/null | grep -c ':'"),
    ]

    for mgr, count_cmd in pkg_mgrs:
        if which(mgr):
            ver = get_version(mgr)
            count = run(count_cmd)
            info["pkg_managers"].append({"name": mgr, "version": ver, "count": count})

    # Key software by category
    dev_tools = ["git", "make", "cmake", "gcc", "g++", "clang", "docker", "docker-compose",
                 "podman", "kubectl", "terraform", "ansible"]
    languages = ["python3", "python", "node", "go", "rustc", "java", "dotnet", "ruby", "php", "perl", "lua"]
    editors = ["code", "nvim", "vim", "nano", "emacs", "subl"]
    browsers = ["firefox", "google-chrome-stable", "chromium", "brave-browser"]
    databases = ["mongod", "postgres", "mysql", "redis-server", "sqlite3"]
    containers = ["docker", "podman", "containerd", "nerdctl"]
    communication = ["slack", "telegram-desktop", "discord", "zoom"]
    media = ["gimp", "inkscape", "blender", "obs", "vlc", "mpv"]
    system_utils = ["htop", "btop", "tmux", "screen", "rsync", "curl", "wget", "jq", "fzf", "ripgrep", "fd"]

    categories = {
        "Development Tools": dev_tools,
        "Languages & Runtimes": languages,
        "Editors & IDEs": editors,
        "Browsers": browsers,
        "Databases": databases,
        "Containers & VMs": containers,
        "Communication": communication,
        "Media & Design": media,
        "System Utilities": system_utils,
    }

    for cat, tools in categories.items():
        found = []
        for tool in tools:
            path = which(tool)
            if path:
                ver = get_version(tool)
                found.append({"name": tool, "version": ver, "path": path})
        if found:
            info["categories"][cat] = found

    return info


def scan_dev_environment() -> Dict:
    """Scan dev-specific: SDKs, version managers, IDE configs, env vars, git."""
    info = {}

    # Version managers
    vm = []
    if which("nvm") or os.environ.get("NVM_DIR"):
        vm.append({"name": "nvm", "for": "Node.js", "active": run("node --version 2>/dev/null")})
    if which("pyenv"):
        vm.append({"name": "pyenv", "for": "Python", "active": run("pyenv version-name 2>/dev/null")})
    if which("rustup"):
        vm.append({"name": "rustup", "for": "Rust", "active": run("rustc --version 2>/dev/null").split()[-1] if run("rustc --version 2>/dev/null") else ""})
    if which("sdkman") or Path.home().joinpath(".sdkman").exists():
        vm.append({"name": "sdkman", "for": "Java/Kotlin", "active": run("java -version 2>&1 | head -1")})
    if which("rbenv"):
        vm.append({"name": "rbenv", "for": "Ruby", "active": run("rbenv version-name 2>/dev/null")})
    info["version_managers"] = vm

    # Key env vars
    important_vars = ["HOME", "USER", "EDITOR", "VISUAL", "TERM", "LANG",
                      "XDG_CONFIG_HOME", "XDG_DATA_HOME", "GOPATH", "CARGO_HOME",
                      "NVM_DIR", "JAVA_HOME", "ANDROID_HOME", "UNITY_PATH"]
    info["env_vars"] = {k: os.environ.get(k, "") for k in important_vars if os.environ.get(k)}

    # PATH entries (deduplicated, interesting ones)
    path_entries = os.environ.get("PATH", "").split(":")
    info["path"] = [p for p in path_entries if p and not p.startswith("/usr/bin") and not p.startswith("/usr/local/bin") and not p.startswith("/bin")]

    # Git config
    info["git_name"] = run("git config --global user.name 2>/dev/null")
    info["git_email"] = run("git config --global user.email 2>/dev/null")
    info["git_editor"] = run("git config --global core.editor 2>/dev/null")

    return info


def scan_services_network() -> Dict:
    """Scan running services, ports, network, SSH."""
    info = {}

    # Services (top 30 by relevance)
    if OS == "linux":
        services_raw = run("systemctl list-units --type=service --state=running --no-legend 2>/dev/null")
        info["services"] = []
        for line in services_raw.split("\n")[:30]:
            parts = line.split()
            if parts:
                name = parts[0].replace(".service", "")
                info["services"].append(name)

        # Listening ports
        ports_raw = run("ss -tlnp 2>/dev/null")
        info["ports"] = []
        for line in ports_raw.split("\n")[1:]:
            parts = line.split()
            if len(parts) >= 6:
                addr = parts[3]
                process = re.search(r'"(\w+)"', parts[-1])
                info["ports"].append({
                    "address": addr,
                    "process": process.group(1) if process else ""
                })

    # Network interfaces
    if OS == "linux":
        ip_out = run("ip -brief addr 2>/dev/null")
        info["interfaces"] = []
        for line in ip_out.split("\n"):
            parts = line.split()
            if len(parts) >= 2 and parts[1] == "UP":
                info["interfaces"].append({
                    "name": parts[0],
                    "ip": parts[2].split("/")[0] if len(parts) > 2 else ""
                })

    # SSH keys
    ssh_dir = Path.home() / ".ssh"
    info["ssh_keys"] = []
    if ssh_dir.exists():
        for f in ssh_dir.iterdir():
            if f.suffix == ".pub":
                content = f.read_text().strip()
                parts = content.split()
                info["ssh_keys"].append({
                    "file": f.name,
                    "type": parts[0] if parts else "",
                    "comment": parts[-1] if len(parts) > 2 else ""
                })

    # SSH config hosts
    ssh_config = Path.home() / ".ssh" / "config"
    info["ssh_hosts"] = []
    if ssh_config.exists():
        try:
            current_host = None
            for line in ssh_config.read_text().split("\n"):
                line = line.strip()
                if line.lower().startswith("host ") and "*" not in line:
                    current_host = {"alias": line.split(None, 1)[1]}
                elif current_host:
                    if line.lower().startswith("hostname"):
                        current_host["hostname"] = line.split(None, 1)[1]
                    elif line.lower().startswith("user"):
                        current_host["user"] = line.split(None, 1)[1]
                    elif line == "" and current_host.get("alias"):
                        info["ssh_hosts"].append(current_host)
                        current_host = None
            if current_host and current_host.get("alias"):
                info["ssh_hosts"].append(current_host)
        except (PermissionError, OSError):
            pass

    return info


def scan_dotfiles() -> Dict:
    """Scan shell config, aliases, key config files."""
    info = {}
    home = Path.home()

    # Shell configs
    rc_files = [".bashrc", ".zshrc", ".bash_profile", ".zprofile", ".profile",
                ".config/fish/config.fish"]
    info["rc_files"] = []
    for rc in rc_files:
        p = home / rc
        if p.exists():
            info["rc_files"].append(str(rc))

    # Aliases (from current shell)
    aliases_raw = run("alias 2>/dev/null")
    info["aliases"] = []
    for line in aliases_raw.split("\n")[:30]:
        line = line.strip()
        if line.startswith("alias "):
            line = line[6:]
        if "=" in line:
            name, cmd = line.split("=", 1)
            info["aliases"].append({"name": name.strip(), "command": cmd.strip().strip("'\"")})

    # Key config dirs
    config_dirs = [".config/nvim", ".config/tmux", ".config/kitty", ".config/alacritty",
                   ".config/hypr", ".config/sway", ".config/i3", ".config/fish",
                   ".config/starship.toml"]
    info["config_files"] = []
    for d in config_dirs:
        p = home / d
        if p.exists():
            info["config_files"].append(d)

    # Dotfile manager
    info["dotfile_manager"] = "none"
    if (home / ".local/share/chezmoi").exists() or which("chezmoi"):
        info["dotfile_manager"] = "chezmoi"
    elif (home / ".cfg").exists() or (home / ".dotfiles").exists():
        info["dotfile_manager"] = "bare git"
    elif which("stow"):
        info["dotfile_manager"] = "stow"

    return info


def parse_yaml_simple(file_path: Path) -> Dict:
    """Simple YAML parser for key: value pairs without external dependency."""
    result = {}
    try:
        for line in file_path.read_text().split("\n"):
            line = line.strip()
            if ":" in line and not line.startswith("#"):
                key, value = line.split(":", 1)
                key = key.strip()
                value = value.strip().strip('"').strip("'")
                # Handle lists as comma-separated, store as string for now
                if value.startswith("[") and value.endswith("]"):
                    value = value[1:-1]  # Remove brackets, keep as string
                result[key] = value
    except (OSError, IOError):
        pass
    return result


def scan_folder_references() -> List[Dict]:
    """Find all .folder-reference/ directories and extract metadata."""
    refs = []
    zones = []
    home = Path.home()

    # Search in home and common project dirs
    search_paths = [home]

    # Also search mounted volumes (top level only)
    if OS == "linux":
        for mount_line in run("findmnt -rn -o TARGET 2>/dev/null").split("\n"):
            p = Path(mount_line.strip())
            if p.exists() and str(p) not in ("/", "/boot", "/boot/efi") and not str(p).startswith("/snap"):
                search_paths.append(p)

    for base in search_paths:
        try:
            # Use find command for speed, max depth 4
            found = run(f"find '{base}' -maxdepth 4 -name '.folder-reference' -type d 2>/dev/null", timeout=15)
            for line in found.split("\n"):
                line = line.strip()
                if not line:
                    continue
                fr_path = Path(line)
                parent = fr_path.parent
                readme = fr_path / "README.md"
                index = fr_path / "index.md"
                meta = fr_path / "meta.yaml"

                # Basic description from README/index
                desc = ""
                for f in [readme, index]:
                    if f.exists():
                        try:
                            first_line = f.read_text().split("\n")[0].strip().lstrip("# ")
                            desc = first_line[:100]
                        except:
                            pass
                        break

                # Check for meta.yaml with zone metadata
                zone_info = None
                if meta.exists():
                    metadata = parse_yaml_simple(meta)
                    domain = metadata.get("domain", "")
                    zone_type = metadata.get("type", "storage")
                    load_rule = metadata.get("load_rule", "on-query")
                    zone_desc = metadata.get("description", desc)

                    if domain or zone_type == "domain":
                        zone_info = {
                            "domain": domain or parent.name,
                            "path": str(parent),
                            "type": zone_type,
                            "load_rule": load_rule,
                            "description": zone_desc or "(no description)"
                        }
                        zones.append(zone_info)

                refs.append({"path": str(parent), "description": desc or "(no description)"})
        except (PermissionError, OSError):
            pass

    # Store zones in a global for generators to use
    global _knowledge_zones
    _knowledge_zones = zones

    return refs


# Global storage for knowledge zones
_knowledge_zones = []


def generate_sys_ask_command(commands_dir: Path) -> None:
    """Generate the /sys-ask command."""
    commands_dir.mkdir(parents=True, exist_ok=True)

    sys_ask_file = commands_dir / "sys-ask.md"
    sys_ask_content = """---
name: sys-ask
description: Ask questions about your system, create knowledge zones, or generate domain commands. Use "создай зону {domain} для {path}" to add zones, "создай команду для {domain}" to generate commands. Loads storage-map and relevant .folder-reference docs.
arguments:
  - name: query
    description: Your question or command (e.g., "какие игры для сеги?", "создай зону emulation для /mnt/Crucial4TB/Emulation", "создай команду для emulation")
    required: true
    greedy: true
---

# /sys-ask

Query your system knowledge, create knowledge zones, or generate domain commands.

## Features

1. **Answer questions** — about storage, domains, software, services
2. **Create knowledge zones** — say "создай зону {domain} для {path}"
3. **Create domain commands** — say "создай команду для {domain}"

## Creating Knowledge Zones

```bash
/sys-ask создай зону emulation для /mnt/Crucial4TB/Emulation
/sys-ask создай зону sega для /mnt/Games/Sega
/sys-ask create zone unity-panda for ~/Work/Panda
```

This creates:
- `.folder-reference/meta.yaml` — zone metadata
- `.folder-reference/README.md` — documentation template
- Updates `storage-map.md` with the new zone

**Zone parameters** (parsed from query or use defaults):
- `domain` — from query (e.g., "emulation")
- `path` — from query (e.g., "/mnt/Crucial4TB/Emulation")
- `type` — defaults to "domain+storage" (can specify: domain/storage/domain+storage)
- `load_rule` — defaults to "always" (can specify: always/on-query/never)
- `description` — extracted from query or defaults to path name

## Creating Domain Commands

```bash
/sys-ask создай команду для emulation
/sys-ask создай команду для sega
/sys-ask create command for unity-panda
```

This generates `~/.claude/commands/sys-{domain}.md` that loads the domain's `.folder-reference/README.md`.

## Process

**First**, check if this is a "create zone" request:
- Patterns: "создай зону {domain} для {path}", "create zone {domain} for {path}"
- Extract: domain, path, optional type/load_rule
- Create `.folder-reference/{meta.yaml, README.md}`
- Run: `python3 scan_system.py --section folders` to update storage-map

**Else if** "create command" request:
- Patterns: "создай команду для {domain}", "create command for {domain}"
- Load `storage-map.md`, find the domain
- Generate `~/.claude/commands/sys-{domain}.md`

**Else** — answer the query:
- Load `storage-map.md`
- Search Knowledge Zones for matching domain/path
- Load `.folder-reference/README.md` if needed
- Return answer

## Examples

```bash
# Ask questions
/sys-ask какие игры для сеги?
/sys-ask где конфиги эмуляторов?

# Create zones
/sys-ask создай зону emulation для /mnt/Crucial4TB/Emulation
/sys-ask создай зону sega storage для /mnt/Games/Sega type storage load_rule on-query

# Create commands
/sys-ask создай команду для emulation
```

---

User query: {{query}}

First, check if this is a "create zone" or "create command" request. If yes, handle accordingly. Otherwise, load storage-map and answer the query.

For zone creation:
1. Parse domain, path from query
2. Create .folder-reference/{meta.yaml, README.md}
3. Run: python3 ~/.claude/skills/system-reference-generator/scripts/scan_system.py --section folders

For command creation:
1. Load storage-map.md
2. Find the domain
3. Generate ~/.claude/commands/sys-{domain}.md
"""
    sys_ask_file.write_text(sys_ask_content)
    print(f"  commands/sys-ask.md")


# ---------------------------------------------------------------------------
# Generators — produce markdown from scan results
# ---------------------------------------------------------------------------

def generate_skill_md(os_info, storage, displays, audio, software, folder_refs) -> str:
    """Generate compact SKILL.md."""
    lines = [
        "---",
        "name: system-reference",
        "description: System environment reference for this machine. Contains OS, hardware, installed software, storage map, displays, audio, dev tools, services, and folder references. Load when working with system tasks, file operations, software installation, troubleshooting, or when context about the user's machine is needed.",
        "---",
        "",
        "# System Reference",
        "",
        f"> Last scanned: {datetime.now().strftime('%Y-%m-%d %H:%M')}",
        "",
        "## System",
        "",
        "| Param | Value |",
        "|-------|-------|",
        f"| Host | {os_info.get('hostname', '')} |",
        f"| OS | {os_info.get('os_name', '')} |",
        f"| Kernel | {os_info.get('kernel', '')} |",
        f"| Shell | {os_info.get('shell', '')} |",
        f"| DE/WM | {os_info.get('de', '')} ({os_info.get('display_server', '')}) |",
        f"| CPU | {os_info.get('cpu_model', '')} ({os_info.get('cpu_cores', '?')}c/{os_info.get('cpu_threads', '?')}t) |",
        f"| RAM | {os_info.get('ram_total', '')} |",
    ]
    for gpu in os_info.get("gpus", []):
        lines.append(f"| GPU | {gpu} |")

    # Key Software
    lines += ["", "## Key Software", "", "| Category | Tools |", "|----------|-------|"]
    pm_names = ", ".join(p["name"] for p in software.get("pkg_managers", []))
    if pm_names:
        lines.append(f"| Package Mgrs | {pm_names} |")
    for cat, tools in software.get("categories", {}).items():
        tool_str = ", ".join(f"{t['name']} {t['version']}" if t['version'] else t['name'] for t in tools[:6])
        lines.append(f"| {cat} | {tool_str} |")

    # Storage
    lines += ["", "## Storage", "", "| Mount | Device | Size | Used | Type |", "|-------|--------|------|------|------|"]
    for m in storage.get("mounts", []):
        lines.append(f"| {m['mount']} | {m['device']} | {m['size']} | {m['use_pct']} | {m.get('fstype', '')} |")

    # Displays
    if displays.get("displays"):
        lines += ["", "## Displays", "", "| Monitor | Resolution | Refresh | Primary |", "|---------|-----------|---------|---------|"]
        for d in displays["displays"]:
            lines.append(f"| {d['name']} | {d.get('resolution', '')} | {d.get('refresh', '')}Hz | {'Yes' if d.get('primary') else 'No'} |")

    # Audio
    if audio.get("sinks"):
        lines += ["", "## Audio", "", "| Device | Type | Default |", "|--------|------|---------|"]
        for s in audio["sinks"]:
            friendly = audio.get("sink_names", {}).get(s["name"], s["name"])
            is_default = "Yes" if s["name"] == audio.get("default_sink") else "No"
            lines.append(f"| {friendly} | Output | {is_default} |")
        for s in audio.get("sources", []):
            friendly = audio.get("source_names", {}).get(s["name"], s["name"])
            is_default = "Yes" if s["name"] == audio.get("default_source") else "No"
            lines.append(f"| {friendly} | Input | {is_default} |")

    # Folder References
    if folder_refs:
        lines += ["", "## Folder References", "", "| Path | Description |", "|------|-------------|"]
        for ref in folder_refs:
            lines.append(f"| `{ref['path']}` | {ref['description']} |")

    # Knowledge Zones
    if _knowledge_zones:
        lines += ["", "## Knowledge Zones", "", "",
                  "**Domain (🏠)** = knowledge area with .folder-reference/README.md — always load before answering",
                  "**Storage (📁)** = files only — can answer with ls/find without loading reference", "", "",
                  "| Domain | Path | Type | Load Rule |",
                  "|--------|------|------|----------|"]
        for z in _knowledge_zones:
            domain = z["domain"] if z.get("domain") else ""
            zone_type = z.get("type", "storage")
            load_rule = z.get("load_rule", "on-query")

            type_emoji = "🏠" if "domain" in zone_type else "📁"
            load_mark = "**ALWAYS**" if load_rule == "always" else load_rule

            lines.append(f"| {domain} | `{z['path']}` | {type_emoji} {zone_type} | {load_mark} |")

        lines += ["", "To add zones: `python3 ~/.claude/skills/system-reference-generator/scripts/scan_system.py --zone-add <path>`"]

    lines += ["", "For details see `references/*.md`", ""]
    return "\n".join(lines)


def generate_os_environment(os_info: Dict) -> str:
    """Generate references/os-environment.md."""
    lines = [
        "# OS & Environment", "",
        "## Operating System", "",
        "| Param | Value |", "|-------|-------|",
        f"| OS | {os_info.get('os_name', '')} |",
        f"| Version | {os_info.get('os_version', '')} |",
        f"| Kernel | {os_info.get('kernel', '')} |",
        f"| Architecture | {os_info.get('arch', '')} |",
        f"| Hostname | {os_info.get('hostname', '')} |",
        "",
        "## Desktop Environment", "",
        "| Param | Value |", "|-------|-------|",
        f"| DE/WM | {os_info.get('de', '')} |",
        f"| Display Server | {os_info.get('display_server', '')} |",
        f"| Session Type | {os_info.get('session_type', '')} |",
        "",
        "## Locale & Time", "",
        "| Param | Value |", "|-------|-------|",
        f"| Language | {os_info.get('lang', '')} |",
        f"| Timezone | {os_info.get('timezone', '')} |",
        "",
        "## Hardware", "",
        "### CPU", "",
        "| Param | Value |", "|-------|-------|",
        f"| Model | {os_info.get('cpu_model', '')} |",
        f"| Cores | {os_info.get('cpu_cores', '')} physical / {os_info.get('cpu_threads', '')} logical |",
        "",
        "### Memory", "",
        "| Type | Total | Used | Available |", "|------|-------|------|-----------|",
        f"| RAM | {os_info.get('ram_total', '')} | {os_info.get('ram_used', '')} | {os_info.get('ram_avail', '')} |",
        f"| Swap | {os_info.get('swap_total', '')} | {os_info.get('swap_used', '')} | |",
        "",
        "### GPU", "",
        "| GPU | Driver | VRAM |", "|-----|--------|------|",
    ]
    for gpu in os_info.get("gpus", []):
        lines.append(f"| {gpu} | {os_info.get('nvidia_driver', '')} | {os_info.get('nvidia_vram', '')} |")

    lines += [
        "",
        "## Shell", "",
        "| Param | Value |", "|-------|-------|",
        f"| Default | {os_info.get('shell', '')} |",
        f"| Version | {os_info.get('shell_version', '')} |",
    ]
    return "\n".join(lines)


def generate_storage_map(storage: Dict, zones: List[Dict] = None) -> str:
    """Generate references/storage-map.md."""
    lines = [
        "# Storage Map", "",
        "## Disks", "",
        "| Device | Size | Type | Model |", "|--------|------|------|-------|",
    ]
    for d in storage.get("disks", []):
        lines.append(f"| {d['name']} | {d['size']} | {d['type']} | {d['model']} |")

    lines += ["", "## Mount Points", "", "| Mount | Device | FS | Size | Used | Avail | Use% |",
              "|-------|--------|-----|------|------|-------|------|"]
    for m in storage.get("mounts", []):
        lines.append(f"| {m['mount']} | {m['device']} | {m.get('fstype', '')} | {m['size']} | {m['used']} | {m['avail']} | {m['use_pct']} |")

    lines += ["", "## Key Directories", ""]
    for mount, dirs in storage.get("key_dirs", {}).items():
        lines.append(f"### {mount}")
        lines += ["", "| Directory | Purpose |", "|-----------|---------|"]
        for d in dirs:
            lines.append(f"| `{d}/` | |")
        lines.append("")

    # Knowledge Zones section
    if zones:
        lines += ["", "## Knowledge Zones", ""]
        lines.append("| Domain | Path | Type | Load Rule | Description |")
        lines.append("|--------|------|------|----------|-------------|")
        for z in zones:
            domain = z["domain"] if z.get("domain") else ""
            zone_type = z.get("type", "storage")
            load_rule = z.get("load_rule", "on-query")

            # Format load rule with emphasis
            if load_rule == "always":
                load_formatted = "**ALWAYS**"
            elif load_rule == "never":
                load_formatted = "never"
            else:
                load_formatted = "on-query"

            # Add domain emoji based on type
            type_display = zone_type
            if "domain" in zone_type:
                type_display = f"🏠 {zone_type}"
            else:
                type_display = f"📁 {zone_type}"

            lines.append(f"| {domain} | `{z['path']}` | {type_display} | {load_formatted} | {z.get('description', '')} |")
        lines.append("")

    return "\n".join(lines)


def generate_displays_audio(displays: Dict, audio: Dict) -> str:
    """Generate references/displays-audio.md."""
    lines = ["# Displays & Audio", ""]

    lines += ["## Displays", "", "| Monitor | Resolution | Refresh | Position | Primary |",
              "|---------|-----------|---------|----------|---------|"]
    for d in displays.get("displays", []):
        lines.append(f"| {d['name']} | {d.get('resolution', '')} | {d.get('refresh', '')}Hz | {d.get('position', '')} | {'Yes' if d.get('primary') else 'No'} |")

    lines += ["", "## Audio Output", "", "| Device | Description | Default |", "|--------|-------------|---------|"]
    for s in audio.get("sinks", []):
        friendly = audio.get("sink_names", {}).get(s["name"], s["name"])
        is_default = "Yes" if s["name"] == audio.get("default_sink") else "No"
        lines.append(f"| {s['name']} | {friendly} | {is_default} |")

    lines += ["", "## Audio Input", "", "| Device | Description | Default |", "|--------|-------------|---------|"]
    for s in audio.get("sources", []):
        friendly = audio.get("source_names", {}).get(s["name"], s["name"])
        is_default = "Yes" if s["name"] == audio.get("default_source") else "No"
        lines.append(f"| {s['name']} | {friendly} | {is_default} |")

    return "\n".join(lines)


def generate_software(software: Dict) -> str:
    """Generate references/installed-software.md."""
    lines = ["# Installed Software", ""]

    lines += ["## Package Managers", "", "| Manager | Version | Packages |", "|---------|---------|----------|"]
    for pm in software.get("pkg_managers", []):
        lines.append(f"| {pm['name']} | {pm['version']} | {pm['count']} installed |")

    for cat, tools in software.get("categories", {}).items():
        lines += ["", f"## {cat}", "", "| Tool | Version | Path |", "|------|---------|------|"]
        for t in tools:
            lines.append(f"| {t['name']} | {t['version']} | `{t['path']}` |")

    return "\n".join(lines)


def generate_dev_environment(dev: Dict) -> str:
    """Generate references/dev-environment.md."""
    lines = ["# Dev Environment", ""]

    if dev.get("version_managers"):
        lines += ["## Version Managers", "", "| Manager | For | Active |", "|---------|-----|--------|"]
        for vm in dev["version_managers"]:
            lines.append(f"| {vm['name']} | {vm['for']} | {vm['active']} |")

    if dev.get("env_vars"):
        lines += ["", "## Key Environment Variables", "", "| Variable | Value |", "|----------|-------|"]
        for k, v in dev["env_vars"].items():
            lines.append(f"| `{k}` | `{v}` |")

    if dev.get("path"):
        lines += ["", "## PATH (non-standard entries)", "", "```"]
        for p in dev["path"]:
            lines.append(p)
        lines.append("```")

    lines += [
        "", "## Git Config", "",
        "| Param | Value |", "|-------|-------|",
        f"| user.name | {dev.get('git_name', '')} |",
        f"| user.email | {dev.get('git_email', '')} |",
        f"| core.editor | {dev.get('git_editor', '')} |",
    ]
    return "\n".join(lines)


def generate_services_network(svc: Dict) -> str:
    """Generate references/services-network.md."""
    lines = ["# Services & Network", ""]

    if svc.get("services"):
        lines += ["## Running Services", "", "| Service |", "|---------|"]
        for s in svc["services"][:30]:
            lines.append(f"| {s} |")

    if svc.get("ports"):
        lines += ["", "## Listening Ports", "", "| Address | Process |", "|---------|---------|"]
        for p in svc["ports"][:20]:
            lines.append(f"| {p['address']} | {p['process']} |")

    if svc.get("interfaces"):
        lines += ["", "## Network Interfaces", "", "| Interface | IP |", "|-----------|-----|"]
        for i in svc["interfaces"]:
            lines.append(f"| {i['name']} | {i['ip']} |")

    if svc.get("ssh_keys"):
        lines += ["", "## SSH Keys", "", "| File | Type | Comment |", "|------|------|---------|"]
        for k in svc["ssh_keys"]:
            lines.append(f"| {k['file']} | {k['type']} | {k['comment']} |")

    if svc.get("ssh_hosts"):
        lines += ["", "## SSH Config Hosts", "", "| Host | Hostname | User |", "|------|----------|------|"]
        for h in svc["ssh_hosts"]:
            lines.append(f"| {h.get('alias', '')} | {h.get('hostname', '')} | {h.get('user', '')} |")

    return "\n".join(lines)


def generate_dotfiles(dotfiles: Dict) -> str:
    """Generate references/dotfiles-config.md."""
    lines = ["# Dotfiles & Config", ""]

    lines += ["## Shell Config Files", "", "| File |", "|------|"]
    for f in dotfiles.get("rc_files", []):
        lines.append(f"| `~/{f}` |")

    if dotfiles.get("aliases"):
        lines += ["", "## Key Aliases", "", "| Alias | Command |", "|-------|---------|"]
        for a in dotfiles["aliases"][:20]:
            lines.append(f"| `{a['name']}` | `{a['command'][:80]}` |")

    if dotfiles.get("config_files"):
        lines += ["", "## Config Directories", "", "| Path |", "|------|"]
        for c in dotfiles["config_files"]:
            lines.append(f"| `~/{c}` |")

    lines += [
        "", "## Dotfile Manager", "",
        "| Param | Value |", "|-------|-------|",
        f"| Manager | {dotfiles.get('dotfile_manager', 'none')} |",
    ]
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

SECTIONS = ["os", "storage", "displays", "audio", "software", "dev", "services", "dotfiles", "folders"]


def add_zone_interactive(path: Path, output: Path):
    """Interactively create a .folder-reference with meta.yaml."""
    if not path.exists():
        print(f"❌ Path does not exist: {path}")
        return

    fr_path = path / ".folder-reference"
    fr_path.mkdir(exist_ok=True)

    print(f"\n📁 Creating zone for: {path}\n")

    # Get description
    desc = input("Description (short): ").strip() or path.name

    # Get domain
    domain = input(f"Domain name (press Enter to skip for storage-only): ").strip() or ""

    # Get type
    print("\nType options:")
    print("  1) domain — knowledge area only")
    print("  2) storage — files only")
    print("  3) domain+storage — both")
    type_choice = input("Choose type [1-3] (default: 2): ").strip() or "2"
    type_map = {"1": "domain", "2": "storage", "3": "domain+storage"}
    zone_type = type_map.get(type_choice, "storage")

    # Get load rule
    print("\nWhen to load reference:")
    print("  1) always — load for ALL questions about this domain")
    print("  2) on-query — only when listing/searching files")
    print("  3) never — context only")
    load_choice = input("Choose [1-3] (default: 2): ").strip() or "2"
    load_map = {"1": "always", "2": "on-query", "3": "never"}
    load_rule = load_map.get(load_choice, "on-query")

    # Write meta.yaml
    meta_content = f"""# Zone metadata for {path.name}
domain: {domain}
type: {zone_type}
load_rule: {load_rule}
description: {desc}
"""
    (fr_path / "meta.yaml").write_text(meta_content)

    # Create README.md if not exists
    readme_path = fr_path / "README.md"
    if not readme_path.exists():
        readme_content = f"""# {desc}

## Location
`{path}`

## Contents
<!-- Add details about what's in this folder -->

## Usage Notes
<!-- Add any important notes for Claude -->
"""
        readme_path.write_text(readme_content)

    print(f"\n✅ Zone created:")
    print(f"   {fr_path}/meta.yaml")
    print(f"   {fr_path}/README.md")
    print(f"\n⚡ Update: python3 {__file__} --section folders")
    print(f"   (generates /sys-{domain} command and updates storage-map)")


def main():
    parser = argparse.ArgumentParser(description="System Reference Scanner")
    parser.add_argument("--output", type=Path, default=Path.home() / ".claude/skills/system-reference",
                        help="Output directory (default: ~/.claude/skills/system-reference)")
    parser.add_argument("--section", choices=SECTIONS, help="Rescan only a specific section")
    parser.add_argument("--zone-add", type=Path, metavar="PATH",
                        help="Interactively add a knowledge zone for PATH")
    args = parser.parse_args()

    # Handle --zone-add separately
    if args.zone_add:
        add_zone_interactive(args.zone_add, args.output)
        return

    output = args.output
    refs_dir = output / "references"
    scripts_dir = output / "scripts"

    # Create dirs
    refs_dir.mkdir(parents=True, exist_ok=True)
    scripts_dir.mkdir(parents=True, exist_ok=True)

    print(f"Scanning system...")

    sections = [args.section] if args.section else SECTIONS

    # Run scans
    os_info = scan_os_info() if "os" in sections else {}
    storage = scan_storage() if "storage" in sections else {}
    displays = scan_displays() if "displays" in sections else {}
    audio = scan_audio() if "audio" in sections else {}
    software = scan_software() if "software" in sections else {}
    dev = scan_dev_environment() if "dev" in sections else {}
    services = scan_services_network() if "services" in sections else {}
    dotfiles = scan_dotfiles() if "dotfiles" in sections else {}
    folder_refs = scan_folder_references() if "folders" in sections else []

    # Generate files
    if not args.section:
        # Full scan — generate everything
        skill_md = generate_skill_md(os_info, storage, displays, audio, software, folder_refs)
        (output / "SKILL.md").write_text(skill_md)
        print(f"  SKILL.md")

    if "os" in sections:
        (refs_dir / "os-environment.md").write_text(generate_os_environment(os_info))
        print(f"  references/os-environment.md")

    if "storage" in sections:
        (refs_dir / "storage-map.md").write_text(generate_storage_map(storage, _knowledge_zones))
        print(f"  references/storage-map.md")

    if "displays" in sections or "audio" in sections:
        (refs_dir / "displays-audio.md").write_text(generate_displays_audio(displays, audio))
        print(f"  references/displays-audio.md")

    if "software" in sections:
        (refs_dir / "installed-software.md").write_text(generate_software(software))
        print(f"  references/installed-software.md")

    if "dev" in sections:
        (refs_dir / "dev-environment.md").write_text(generate_dev_environment(dev))
        print(f"  references/dev-environment.md")

    if "services" in sections:
        (refs_dir / "services-network.md").write_text(generate_services_network(services))
        print(f"  references/services-network.md")

    if "dotfiles" in sections:
        (refs_dir / "dotfiles-config.md").write_text(generate_dotfiles(dotfiles))
        print(f"  references/dotfiles-config.md")

    # Special case: folders section should also update storage-map with zones
    if "folders" in sections:
        # If only folders section and storage-map exists, preserve storage data
        storage_map_path = refs_dir / "storage-map.md"
        if not storage and storage_map_path.exists():
            # Scan storage to preserve existing data
            print(f"  Scanning storage to preserve existing data...")
            storage = scan_storage()
        (refs_dir / "storage-map.md").write_text(generate_storage_map(storage, _knowledge_zones))
        print(f"  references/storage-map.md (updated with zones)")

        # Generate /sys-ask command (always update to get latest version)
        commands_dir = Path.home() / ".claude" / "commands"
        print(f"  Updating /sys-ask command...")
        generate_sys_ask_command(commands_dir)

    # Copy scan script to output for easy rescan
    src_script = Path(__file__)
    dst_script = scripts_dir / "scan_system.py"
    if src_script.exists():
        shutil.copy2(src_script, dst_script)

    print(f"\nDone! Generated at: {output}")
    print(f"Review: {output}/SKILL.md")


if __name__ == "__main__":
    main()
