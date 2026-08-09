---
name: herdr-orchestrate
description: "Orchestrate a dev task across specialist Herdr panes from the orchestrator pane: delegate implementation and code-verified reviews to other panes (identified by ROLE, discovered at runtime — pane names are arbitrary), write handoff docs as source-of-truth, run review loops (revN→revN.1), forward results back to your own pane, and verify delegated work yourself before trusting it. Use when Regina asks to hand work to another pane/agent, get a cross-check/review, run a multi-pane dev workflow, or 'orchestrate'. Builds ON TOP of the base `herdr` skill (which is pane mechanics). Requires HERDR_ENV=1."
---

# Herdr orchestration

The playbook for coordinating a dev task across specialist Herdr panes. This is the
**orchestration layer**; the base `herdr` skill is the **mechanics** (split/run/wait/
read). Load `herdr` for exact CLI syntax; load this for *how the roles work together*.

You (the `claude-code` pane) are the **orchestrator**: you plan, write handoff docs,
dispatch, verify, and surface scope decisions to Regina. You do NOT do the delegated
implementation or review yourself unless asked — you coordinate and verify.

Precondition: `test "${HERDR_ENV:-}" = 1`. If not in Herdr, say so and stop.

## Roles & pane discovery

Think in **roles**, not fixed names — **pane labels are arbitrary** and set by
whoever made them. Discover which pane fills which role at runtime by reading labels
(and, if ambiguous, the running agent/model); never hardcode a name or id. A label is
also not the same as the runtime: a pane can be labeled for a reviewer role while
running a different agent/model underneath. When the role is unclear from the labels,
ask Regina which pane to use rather than guessing.

- **orchestrator** — you (`claude-code`). Your own pane id is `$HERDR_PANE_ID` (the
  forward-back target for others).
- **implementer** — a pane that writes code, runs tests, commits when told.
- **reviewer** — a pane that gives code-verified critique (catches wrong assumptions
  about the actual code — that is its value).

In the current setup these happen to be a pane labeled *GLM* (implementer) and one
labeled *Codex* (reviewer, often `pi` on a GPT model) — but treat those as examples,
match by role.

**Runtime & model assignment (preferred):** match by role, then pick the runtime.

| Role / model | Runtime | Why |
|--------------|---------|-----|
| **Implementation** | **pi** | pi is the preferred runtime for writing code. |
| **Codex / GPT models** | **pi** | Run Codex *inside* pi (pi on a GPT/codex model), not as a standalone codex pane. |
| **Opus, Fable** | **claude-code only** | These Claude models must run in claude-code, never in pi. |

So a typical workspace: implementer = pi (GLM or GPT), reviewer = pi (GPT/codex) or
claude-code (Opus/Fable). The orchestrator (you) is whatever pane launched the
orchestration — often pi or claude-code.

Discover live panes and read the label + status (do not hardcode ids — reread after
any change):

```bash
herdr pane list --workspace "$HERDR_WORKSPACE_ID" 2>/dev/null | python3 -c "
import sys,json
for p in json.load(sys.stdin)['result']['panes']:
    print(p['pane_id'],'|',p.get('label',''),'|',p.get('agent',''),'|',p.get('agent_status',''))
"
```

If the needed role has no pane, create one. Prefer the **`herdr-spawn`** helper
(this skill's `bin/herdr-spawn`) — it does split + label + launch + wait-idle in
one shot, picks direction from pane shape, defaults to `pi`, and retries past the
fresh-shell startup race:

```bash
PANE=$(~/.agents/skills/herdr-orchestrate/bin/herdr-spawn implementer-GLM)   # → pi
PANE=$(~/.agents/skills/herdr-orchestrate/bin/herdr-spawn reviewer claude)    # → claude-code
```

It prints the new `pane_id` on stdout. (The raw sequence, if you ever need it:
base `herdr` skill — split `--no-focus`, rename to the role, `run` the agent's
executable, wait for `idle`.) `herdr-spawn` retries past the fresh-shell startup
race (the agent launch is re-sent until detected).

**Before launching/relaunching an agent on an EXISTING (reused) pane by hand,
clear stray input first** — a reused pane may carry leftover characters from
aborted sends (e.g. a partial `pi` from a failed launch, or a stray letter),
which prefix and corrupt the next command. `herdr pane send-keys <pane> C-c`
cancels any partial line. ⚠️ Do this ONLY on a stable, already-initialized pane
— on a freshly-split pane `C-c` can interrupt the shell mid-init (truncating its
profile/PATH), leaving the agent executable not found. `herdr-spawn` correctly
avoids sanitizing fresh splits for this reason.

**To CHANGE an agent (e.g. pi+GLM → claude+Opus), close + respawn — don't try
in-place.** Exiting a running agent by sending `/quit` or Ctrl+D is a PTY
input-delivery race (sometimes the Enter becomes a newline, sometimes it's lost
mid-render) and is unreliable, which is why the base herdr skill documents no
agent-exit at all. The reliable move is a fresh pane with the same role label:

```bash
herdr pane close <old_pane>
PANE=$(~/.agents/skills/herdr-orchestrate/bin/herdr-spawn implementer claude)
```

The new pane gets a new `pane_id`, but role-based discovery (re-read `pane list`)
handles that — never hardcode pane ids.

## Source-of-truth docs: design vs handoff

Split the writing in two, both in `docs/specs/`:

- **design/plan doc** — *what & why*: architecture, code facts (cite `file:line`),
  decisions, non-goals, open questions. This is what the reviewer critiques and what
  revisions (rev1 → rev1.1 → …) iterate on.
- **handoff doc** — *how & in what order*: build order (`T1..Tn`), each task's files/
  tests/acceptance, a **verification** section, and a **"do NOT"** section. References
  the design as source of truth. This is what the implementer executes.

Every handoff repeats the standing constraints (see below) so the delegated agent
can't miss them.

**Ping-back convention (required — make it self-contained).** Whenever a
handoff/dispatch needs a result back (a review, or any task whose output you must
consume), put the **complete, ready-to-run ping-back command inline** in the
handoff, with your pane id already resolved to a literal (e.g. `w2:p1`) — not a
placeholder like `$HERDR_PANE_ID`, because the command runs in the other pane's
environment, not yours:

```
Write the result to <path>, then run EXACTLY this (do NOT load any herdr skill):
  herdr pane run w2:p1 "<role> готов: <path> — <one-line verdict>"
```

⚠️ **Author the string so your shell doesn't leak your context.** Any `$VAR`
inside the task text — including `$HERDR_PANE_ID` — expands in YOUR shell before
the delegated agent ever sees it. So the ping-back command must carry the RESOLVED
literal pane id (`w2:p1`), and descriptive text must never use `$HERDR_PANE_ID`
meaning the delegated agent's OWN pane — it'll be yours.

The point: the delegated agent should **not need to load the herdr skill** or guess
the destination — it just runs the command you wrote. That keeps its context lean and
guarantees the result lands back in YOUR pane (you commissioned the work) as a turn.
Long content goes to a file first — `pane run` args are fragile with newlines, so the
ping is just a short pointer.

## Dispatch a task to a pane

**`/new` before unrelated work (context hygiene).** When you hand a pane a NEW
task UNRELATED to what it just did, clear its context first (`/new` in pi; the
runtime's clear/new command otherwise) so stale assumptions don't bleed in. As a
rule this applies to **implementation** dispatches. The exception: iterative
**cross-review** on the SAME artifact (rev1 → rev1.1 → …) — there you keep the
context (no `/new`), because the reviewer's accumulated understanding is the point.

```bash
# Clear context when the next task is UNRELATED to the pane's last work
# (skip for iterative cross-review on the same artifact):
herdr pane run <implementer_pane_id> '/new'                # pi: new session

herdr pane run <pane_id> '<task text — point at the source-of-truth doc, state
constraints, and for reviews/handoffs the forward-back instruction>'
herdr wait agent-status <pane_id> --status working --timeout 30000   # confirm pickup
```

Then let it run in the background (you are re-invoked, or poll with `pane get`). When
it reports `done`/`idle`, read its transcript (`pane read --source recent-unwrapped`)
or the artifact it wrote.

Independent workstreams run in **parallel** (implementer on one track, reviewer on
another) — just watch for file overlap; note it if two panes touch the same files.

## Delivery model: async ping vs sync poll

Two ways to receive a delegated result. **Don't mix them** — that's how pings
land in a queue behind your own busy turn.

**Async (default for ping-backs).** Dispatch, then **END your turn** (go idle). When
the delegated agent finishes and runs the literal ping-back command you gave it, that
input arrives in YOUR pane as a fresh turn — it re-invokes you (this is what
"you are re-invoked" above means). For this to work your pane must be **idle**: if
you stay `working` (e.g. blocked in a synchronous `herdr wait` in your own shell),
the ping **queues** and is only delivered once you go idle. `herdr pane run <you>`
always returns exit 0 immediately — delivery into a busy agent is deferred, not
signaled by the command's output.

**Sync (polling — stay in control).** Don't end the turn; pull the result yourself:
```bash
# completion status depends on whether the delegate's tab is being watched:
#   active/watched tab  → completes to `idle`   (the common case while you orchestrate)
#   background/unseen tab → completes to `done`
# `herdr wait --status` takes ONE status, so pick by topology. Default: `idle`.
herdr wait agent-status <pane_id> --status idle --timeout 120000   # it finished
herdr pane read   <pane_id> --source recent-unwrapped --lines 120  # read its answer
```
Don't wait on `done` if you're orchestrating in the same active tab — the delegate
completes to `idle` (its result is "seen" because the tab is foreground), so
`wait done` hangs forever. `done` only appears for a delegate in a background/
unseen tab. When unsure, poll `herdr pane get <id>` and treat **either** `idle` or
`done` as completed (never `working`). Here you do NOT rely on a ping to interrupt you.

**Prefer sync for unattended work.** If the user signals overnight/night work, says
they're stepping away, or explicitly asks for polling — choose sync. The async
re-invocation chain can silently break (a provider drops mid-handoff, the
orchestrator pane dies, a ping fails to land) and with nobody watching there's no
recovery. Sync keeps you in the driver's seat: you catch a dropped delegate
(`agent_status` stuck on `working`, empty/erroring transcript) and can retry or
escalate deterministically instead of hoping a ping arrives.

**Rule of thumb:** blocking synchronously ⟹ read the transcript (never wait on a
ping). Want the ping to re-invoke you ⟹ go idle (end the turn). Expecting a ping to
interrupt a synchronous wait is the bug — the ping silently queues.

## The review loop

1. Dispatch a **code-verified** review of the design doc to the reviewer pane. Ask it
   to check specific claims *against the actual code* (cite the `file:line` you're
   asserting), not just opine.
2. Tell it to **write the full review to a file** and then **run the literal
   ping-back command you put in the handoff** (see Ping-back convention — complete,
   with your pane id resolved, so it needs no herdr skill):
   ```
   herdr pane run w2:p1 "<role> review готов: <path> — <verdict one line>"
   ```
   (File for the long content — `pane run` args are fragile with newlines; the ping is
   a short pointer that lands in your conversation as a turn.)
3. Read the file, **triage by severity**, and **accept code-verified feedback** — the
   reviewer has read the code you may have only assumed about. Fold accepted findings
   into `revN.1`; re-dispatch if the scope materially changed.
4. **Surface genuine scope forks to Regina** (e.g. "full multi-user vs v0 single-user")
   via AskUserQuestion — don't decide product/deployment scope yourself.
5. Stop iterating when the reviewer says implementation-ready (or the residual items
   are explicitly deferred with the reason recorded).

## Verify-before-trust (non-negotiable)

Never relay a delegated agent's "✅ done" at face value. Before reporting to Regina,
check it yourself:

- **git:** `git log --oneline`, `git show --stat <commit>` — the file list matches
  what was scoped; on a **dirty tree**, confirm the committed hunks contain ONLY the
  intended change (`git show <commit> -- <file>`), no leakage from parallel sessions.
- **tests:** run them (`node <test>`, `pytest …`) — don't trust the reported pass.
- **invariants:** spot-check the sacred ones (e.g. a byte-identical file, a no-op path).
- **live effect:** where cheap, confirm the real outcome (endpoint 200, row counts).

Report faithfully: what passed, what was skipped, what's still the user's step.

## Standing constraints to carry into every dispatch

- **plan-first** — design/handoff before code; code only after Regina's go-ahead.
- **dirty-tree staging** — stage only the named files; never `git add -A` / `commit -a`;
  use selective staging on files with mixed parallel-session changes.
- **no commit/push without Regina's explicit go-ahead.**
- **"if you find a real contract gap, STOP and describe it — don't improvise."**
- keep out-of-repo work (crontab, `~/.hermes/scripts/*`) out of commits; leave Regina
  a note for anything that's her domain.

## Record the outcome in memory

After a delegated task lands + is verified, update the relevant project memory
(`memory/…`) with the state, commit hashes, and any deferred items — so the next
session knows where things stand. See the project memory index for the file.
