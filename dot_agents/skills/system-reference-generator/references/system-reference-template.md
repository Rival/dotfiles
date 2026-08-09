# System Reference SKILL.md Template

This is the template for the generated `~/.claude/skills/system-reference/SKILL.md`.

```markdown
---
name: system-reference
description: System environment reference for this machine. Contains OS, hardware, installed software, storage map, displays, audio, dev tools, services, and folder references. Load when working with system tasks, file operations, software installation, troubleshooting, or when context about the user's machine is needed.
---

# System Reference

Personal system passport. Compact summary below; details in references/*.md.

## System

| Param | Value |
|-------|-------|
| Host | {hostname} |
| OS | {os_name} {os_version} |
| Kernel | {kernel_version} |
| Shell | {shell} |
| DE/WM | {desktop_environment} |
| CPU | {cpu_model} |
| RAM | {ram_total} |
| GPU | {gpu_model} |

## Key Software

| Category | Tools |
|----------|-------|
| Package Mgrs | {pkg_managers} |
| Dev | {dev_tools} |
| Languages | {languages_with_versions} |
| Editors/IDE | {editors} |
| Containers | {container_tools} |
| Browsers | {browsers} |
| DB | {databases} |

## Storage

| Mount | Device | Size | Used | Type | Purpose |
|-------|--------|------|------|------|---------|
| {mount} | {device} | {size} | {used}% | {fstype} | {label/purpose} |

## Displays

| Monitor | Resolution | Refresh | Position |
|---------|-----------|---------|----------|
| {name} | {res} | {hz}Hz | {pos} |

## Audio

| Device | Type | Default |
|--------|------|---------|
| {name} | {sink/source} | {yes/no} |

## Folder References

| Path | Description |
|------|-------------|
| {path} | {from .folder-reference/README.md first line} |

For details: `references/os-environment.md`, `references/installed-software.md`, etc.
```
