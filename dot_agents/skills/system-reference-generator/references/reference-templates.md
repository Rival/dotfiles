# Reference File Templates

Templates for each `references/*.md` file in the generated system-reference.

## os-environment.md

```markdown
# OS & Environment

## Operating System

| Param | Value |
|-------|-------|
| Distribution | {distro} |
| Version | {version} |
| Kernel | {kernel} |
| Architecture | {arch} |
| Hostname | {hostname} |
| Uptime | {uptime} |

## Desktop Environment

| Param | Value |
|-------|-------|
| DE/WM | {de} |
| Display Server | {x11/wayland} |
| Session Type | {session} |
| Theme | {theme} |

## Locale & Time

| Param | Value |
|-------|-------|
| Language | {lang} |
| Timezone | {tz} |
| Encoding | {encoding} |

## Hardware

### CPU

| Param | Value |
|-------|-------|
| Model | {model} |
| Cores | {physical} physical / {logical} logical |
| Freq | {freq} |

### Memory

| Type | Total | Used | Available |
|------|-------|------|-----------|
| RAM | {total} | {used} | {avail} |
| Swap | {total} | {used} | {avail} |

### GPU

| GPU | Driver | VRAM |
|-----|--------|------|
| {model} | {driver} | {vram} |

## Shell

| Param | Value |
|-------|-------|
| Default | {shell} |
| Version | {version} |
| Framework | {oh-my-zsh/starship/etc} |
```

## installed-software.md

```markdown
# Installed Software

## Package Managers

| Manager | Version | Packages |
|---------|---------|----------|
| {name} | {ver} | {count} installed |

## By Category

### Development Tools

| Tool | Version | Installed Via |
|------|---------|---------------|
| {name} | {ver} | {pkg_manager} |

### Languages & Runtimes

| Language | Version | Path |
|----------|---------|------|
| {name} | {ver} | {path} |

### Editors & IDEs

| Editor | Version |
|--------|---------|
| {name} | {ver} |

### Browsers

| Browser | Version |
|---------|---------|
| {name} | {ver} |

### Containers & VMs

| Tool | Version |
|------|---------|
| {name} | {ver} |

### Databases

| DB | Version | Status |
|----|---------|--------|
| {name} | {ver} | {running/stopped} |

### Communication

| App | Version |
|-----|---------|
| {name} | {ver} |

### Media & Design

| App | Version |
|-----|---------|
| {name} | {ver} |

### System Utilities

| Tool | Version |
|------|---------|
| {name} | {ver} |
```

## storage-map.md

```markdown
# Storage Map

## Disks & Partitions

| Device | Size | Type | Model |
|--------|------|------|-------|
| {dev} | {size} | {ssd/hdd/nvme} | {model} |

## Mount Points

| Mount | Device | Filesystem | Size | Used | Available | Use% |
|-------|--------|-----------|------|------|-----------|------|
| {mount} | {dev} | {fs} | {size} | {used} | {avail} | {pct}% |

## Key Directories

### {mount_point}

| Directory | Purpose | Approx Size |
|-----------|---------|-------------|
| {path} | {desc} | {size} |
```

## displays-audio.md

```markdown
# Displays & Audio

## Displays

| Monitor | Connection | Resolution | Refresh | Position | Primary |
|---------|-----------|-----------|---------|----------|---------|
| {name} | {hdmi/dp} | {res} | {hz}Hz | {x,y} | {yes/no} |

### Display Config Paths

| What | Path |
|------|------|
| X11 config | {path} |
| Wayland config | {path} |
| KDE monitors | `~/.local/share/kscreen/` |

## Audio

### Output Devices (Sinks)

| Device | Description | Default | Volume |
|--------|-------------|---------|--------|
| {name} | {desc} | {yes/no} | {vol}% |

### Input Devices (Sources)

| Device | Description | Default |
|--------|-------------|---------|
| {name} | {desc} | {yes/no} |

### Audio Config

| What | Path/Command |
|------|-------------|
| PipeWire config | `~/.config/pipewire/` |
| PulseAudio config | `~/.config/pulse/` |
| Volume control | `pavucontrol` / `wpctl` |
```

## dev-environment.md

```markdown
# Dev Environment

## SDKs & Toolchains

| SDK | Version | Path |
|-----|---------|------|
| {name} | {ver} | {path} |

## Version Managers

| Manager | For | Active Version |
|---------|-----|----------------|
| {nvm/pyenv/rustup} | {lang} | {ver} |

## IDE & Editor Config

| Editor | Config Path |
|--------|-------------|
| {name} | {path} |

## Key Environment Variables

| Variable | Value |
|----------|-------|
| PATH (key entries) | {entries} |
| {VAR} | {value} |

## Git Config

| Param | Value |
|-------|-------|
| user.name | {name} |
| user.email | {email} |
| core.editor | {editor} |
```

## services-network.md

```markdown
# Services & Network

## Running Services

| Service | Status | Port | Description |
|---------|--------|------|-------------|
| {name} | {active/inactive} | {port} | {desc} |

## Listening Ports

| Port | Process | Protocol |
|------|---------|----------|
| {port} | {name} | {tcp/udp} |

## Network Interfaces

| Interface | IP | Type |
|-----------|-----|------|
| {name} | {ip} | {ethernet/wifi/vpn} |

## SSH

| Key | Type | Comment |
|-----|------|---------|
| {file} | {rsa/ed25519} | {comment} |

### SSH Config Hosts

| Host | Hostname | User |
|------|----------|------|
| {alias} | {host} | {user} |
```

## dotfiles-config.md

```markdown
# Dotfiles & Config

## Shell Config

| File | Purpose |
|------|---------|
| `~/.zshrc` | Main shell config |
| `~/.bashrc` | Bash config |
| {file} | {purpose} |

## Key Aliases

| Alias | Command |
|-------|---------|
| {alias} | {command} |

## PATH (ordered)

```
{path entries, one per line}
```

## Key Config Files

| Config | Path | Purpose |
|--------|------|---------|
| {name} | {path} | {desc} |

## Dotfile Manager

| Param | Value |
|-------|-------|
| Manager | {chezmoi/stow/bare git/none} |
| Source | {path/repo} |
```
