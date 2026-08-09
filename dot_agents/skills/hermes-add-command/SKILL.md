---
name: hermes-add-command
description: Use when adding, renaming, or debugging a hermes-agent slash command (e.g. "/foo not working", "add a /bar command", Telegram shows the command but it says Unknown command). Covers the plugin command API and the underscore/hyphen Telegram pitfall.
---

# Adding a hermes slash command

## Rule 1 — use the plugin API, not core edits
Register commands from a plugin's `register(ctx)`:

    ctx.register_command("my-cmd", handler, description="…", args_hint="<arg>")

- `handler(raw_args: str) -> str | None` (sync or async).
- Works in BOTH CLI and gateway. No edits to `hermes_cli/commands.py`,
  `gateway/slash_commands.py`, or `gateway/run.py`.
- Conflicts with built-in commands are rejected with a warning.

Do NOT add a `CommandDef` to `COMMAND_REGISTRY` unless the command is genuinely
core. Patching command handlers into `gateway/run.py` is how the file rotted
into duplicate methods + an IndentationError (2026-06-27 incident).

## Rule 2 — command names: `[a-z0-9-]`, NO underscores
Telegram's `setMyCommands` only accepts `[a-z0-9_]`, so hermes converts
hyphens → underscores for the Telegram menu (`_sanitize_telegram_name`,
`hermes_cli/commands.py:703`). The gateway then normalizes `_` → `-` back
before plugin lookup (`gateway/run.py:8879`).

Net effect:
- Register `my-cmd` (hyphen) → Telegram shows `/my_cmd` → typing it dispatches
  back to `my-cmd`. **Works.**
- Register/define `my_cmd` (underscore) as a built-in → hits inconsistent
  normalization paths → "Unknown command". **Breaks.**

So: always register with the hyphen form. Single-word names (`restart`,
`usage`) are also safe.

## Rule 3 — auto-start sidecars in `register(ctx)`
`register(ctx)` runs on every gateway start (`discover_plugins()`,
`gateway/run.py:5916`). Put idempotent sidecar startup there (probe the port,
spawn only if free). Blocking servers (uvicorn) → detached subprocess; async
servers (aiohttp) → background thread (see mnemosya's `sync_debug_server`).

## Verify
After changing commands, restart the gateway and confirm in Telegram that the
menu entry dispatches (underscores included). Built-in command changes need a
gateway restart; plugin commands load on the next `discover_plugins()`.
