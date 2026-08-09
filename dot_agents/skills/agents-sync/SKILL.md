---
name: agents-sync
description: Use when working on the agent config/skill/command sync system in ~/.agents-system — syncing plugin skills or commands to Codex or Pi, editing sync-plugin-skills.sh or setup-agent-config.sh, adding a new target tool, or debugging missing/broken skill/prompt symlinks in ~/.codex or ~/.pi.
version: 1.0.0
---

# agents-sync

## Overview

One canonical source under `~/.agents/` fanned out to every agent tool (Claude Code, Codex, Pi). Two scripts in `~/.agents-system/scripts/` do it. Claude plugins are the upstream source of truth for skills/commands; personal skills/commands sit alongside; both get mirrored to tools that don't load Claude plugins themselves.

```
┌─ SOURCES ───────────────────────┐   ┌─ CANONS (~/.agents) ─┐   ┌─ TARGETS ──────────────────┐
│ 📦 plugin cache/.../skills/      │   │ 📚 skills/           │──►│ 🤖 Codex  ~/.codex/skills  │
│ 📦 plugin cache/.../commands/*.md│──►│ 📝 commands/         │   │           ~/.codex/prompts │
│ 👤 ~/.claude/commands/*.md       │   │  (symlinks → LIVE    │──►│ 🐇 Pi ~/.pi/agent/skills   │
│ 👤 personal skill dirs           │   │   plugin cache)      │   │       ~/.pi/agent/prompts  │
│ 📄 ~/.claude/CLAUDE.md (AGENTS)  │   │ 📄 AGENTS.md         │──►│    +  AGENTS.md everywhere │
└──────────────────────────────────┘   └──────────────────────┘   └────────────────────────────┘
```

## The two scripts

**`setup-agent-config.sh`** — canonicalizes instructions. Moves `~/.claude/CLAUDE.md` → `~/.agents/AGENTS.md` (canonical), rewrites `CLAUDE.md` into a thin adapter that imports `@~/.agents/AGENTS.md`, and symlinks `~/.codex/AGENTS.md` → canonical. Same MOVE-then-adapter dance for a repo (`CLAUDE.md` → `.agents/AGENTS.md`, root `AGENTS.md` symlink). Idempotent; backs up before overwrite; reports Created/Updated/Skipped/Backed/Conflicts.

**`sync-plugin-skills.sh`** — builds the two canons then mirrors them. Run it after installing/updating any Claude plugin, or adding a personal skill/command. Idempotent.

## Canon layout & naming (in sync-plugin-skills.sh)

- **Skills** are dirs with `SKILL.md`. Canon `~/.agents/skills/<name>` → symlink into live plugin cache. Name = `<plugin>-<skill>`, or just `<plugin>` when skill == plugin. Personal skills are **real dirs** left in place.
- **Commands** are single `.md` files. Canon `~/.agents/commands/<name>.md`. Plugin name = `<plugin>-<command>.md`. Personal commands (`~/.claude/commands/*.md`) are mirrored **first and win collisions**.
- Symlinks point at the **live** cache, so Claude's own plugin updates are picked up with no re-run needed for content (only new/removed skills need a re-run).

## Targets & the mirror helper

`mirror_canon <src_canon> <dst_dir> <rel_prefix> <label>` fans one canon into one tool dir with relative symlinks. It removes only its own stale symlinks (target path contains the canon marker like `/.agents/skills/`), never touches real files or foreign symlinks, and `mkdir -p`s the target. Called 4× behind existence gates:

| Tool | gate | skills dir | commands dir | rel prefix |
|------|------|-----------|--------------|------------|
| Codex | `[ -d ~/.codex ]` | `~/.codex/skills` | `~/.codex/prompts` | `../../.agents/...` |
| Pi | `[ -d ~/.pi/agent ]` | `~/.pi/agent/skills` | `~/.pi/agent/prompts` | `../../../.agents/...` (3× up) |

Tool-specific notes:
- **Codex** reads custom prompts from `~/.codex/prompts/` (NOT `~/.codex/skills`). Built-in skills live under `.system` — untouched.
- **Pi** (`@earendil-works/pi-coding-agent`): skills → `/skill:name`; markdown slash-commands are **"prompt templates"** in `~/.pi/agent/prompts/*.md` → `/name`. Pi's `~/.pi/agent/commands/` is for **TypeScript extensions**, not markdown — do NOT target it. Same md format as Claude/Codex (`description`, `$1`/`$@`/`$ARGUMENTS`, optional `argument-hint`).

## Add a new target tool

1. Find where the tool loads skills and markdown prompts.
2. Add a gated block: `if [ -d <tool_base> ]; then mirror_canon "$CANON" <tool>/skills <relprefix>/.agents/skills "<tool> skills"; mirror_canon "$CANON_CMD" <tool>/prompts <relprefix>/.agents/commands "<tool> prompts"; fi`
3. Get `rel_prefix` right: count dirs from the target up to `$HOME` (Codex = 2, Pi = 3).

## Gotchas

- Extra Claude frontmatter (`allowed-tools`, etc.) is ignored by Codex/Pi — the command body still runs, tool access follows the host tool's own permissions.
- Two-hop symlinks (`tool → canon → cache/personal`) resolve fine.
- `installed_plugins.json` can have duplicate keys (`@local` + `@marketplace`); last one wins silently — harmless.
- **Pluginless hosts work**: when `installed_plugins.json` is absent, the plugin build steps are skipped but the canon is still mirrored to every installed tool. So a host whose canon is populated only by personal skills / skills pushed from another machine still gets them into Codex/Pi.
- **Cross-machine delivery** is a separate concern: `sync-skills-to-remote.sh` (on the source machine) pushes selected skills + this infra into a remote's CANON, then triggers the remote's own `sync-plugin-skills.sh`. The remote never syncs FROM the source's OS — its local agents-sync fans its own canon out. `~/Regina/.pi` was previously "foreign"; selected skills are now delivered to it via that control script.
- `~/.agents-system` is not a git repo; there's no commit step.

## Quick reference

```bash
bash ~/.agents-system/scripts/sync-plugin-skills.sh   # rebuild canons + mirror to Codex/Pi
bash ~/.agents-system/scripts/setup-agent-config.sh   # canonicalize AGENTS.md (global + cwd repo)
ls -la ~/.agents/skills ~/.agents/commands            # inspect canons
readlink -f ~/.pi/agent/prompts/<name>.md             # verify a mirror chain resolves
# (source machine only) deliver selected skills + infra to a remote, then
# trigger its local agents-sync:
bash ~/.agents-system/scripts/sync-skills-to-remote.sh [--dry-run] [skill ...]
```

Expected steady state (current): 59 plugin skills, 6 personal + 7 plugin commands, mirrored as 67 skills / 13 prompts to each installed tool. Re-runs report `removed N = linked N` (idempotent).
