# Graphify query-first hooks

Six small Claude Code hooks that make **"query the knowledge graph before browsing
raw code"** an enforced rule instead of a suggestion. They fire **only** in a repo that
has a `graphify-out/graph.json`; everywhere else they are silent and block nothing.

## Why

A graph Claude routes around is dead weight. A `SessionStart` banner and a per-Grep
reminder are easy to read and ignore. These hooks add teeth: broad code exploration is
**denied** until the graph has actually been consulted. `Read` used to be only a nudge,
which was the whole loophole (grep gets blocked, so you just `Read` your way around the
graph instead). `Read` of code files is now gated too, but scoped so it stays usable.

## The scripts

| Script | Event | Behaviour |
|--------|-------|-----------|
| `graphify-nudge.sh` | `PreToolUse` (Grep\|Glob) | If the repo has a graph and no consult has happened **this turn**, return a `deny` decision telling Claude to run `graphify query`/`path`/`explain` first. |
| `graphify-read-nudge.sh` | `PreToolUse` (Read) | Same gate as above, but scoped: **only code files** are gate-eligible, and the **first `$GRAPHIFY_READ_GRACE` code reads each turn** (default 2, read-before-edit) pass free. Beyond that, reading another code file is `deny`ed until the graph is consulted. Non-code files (docs, config, migrations, fixtures) are always allowed. |
| `graphify-mark.sh` | `PostToolUse` (Bash) | If the command that ran was `graphify query|path|explain|god-nodes|affected|read`, write the per-turn marker, which unblocks Grep/Glob/Read for the rest of the turn. |
| `graphify-reset.sh` | `UserPromptSubmit` | New turn → delete the marker and the code-read counter, so each question needs a fresh consult. |
| `graphify-banner.sh` | `SessionStart` | Announce the graph and the enforced rule. |
| `graphify-audit.sh` | `Stop` | Backstop. If the turn browsed code (grace reads happened) but never consulted the graph, append the miss to `~/.claude/state/graphify-misses.log`. Non-blocking. |

Per-turn state under `~/.claude/state/`, keyed by `<hash-of-project-dir>`:
`graphify-ok.<key>` (the consult marker) and `graphify-reads.<key>` (code-read counter).
`graphify-misses.log` is the persistent audit trail and is **not** reset between turns.

## Design choices (deliberate, not omissions)

- **`Read` of code is gated, but scoped — not blanket-denied.** A blanket Read block is
  blunt: you would `touch` the bypass on every migration, config file, and file you are
  about to edit, and the marker would stop meaning anything. So the gate applies to
  **code-file exploration only**, on two observable signals:
  - **File type.** Only source extensions are gate-eligible; docs/config/migrations/
    fixtures/data always pass. (Edit the `case` list in `graphify-read-nudge.sh` for your
    stack.)
  - **A read-before-edit grace.** A `PreToolUse` hook fires *before* the Read and cannot
    see a *future* Edit, so intent is unobservable. Instead, the first
    `$GRAPHIFY_READ_GRACE` code files each turn pass free: a focused fix touches one or two
    files (never blocked), exploration fans out across many (blocked past the grace).
- **A hook cannot read intent.** It cannot tell a code-question grep from a legitimate
  exact-string search, nor an exploration read from a read-before-edit. So there is an
  escape hatch: `touch` the marker named in the deny message. Because that shows up in the
  transcript, skipping the graph becomes a conscious, logged act, which is the right amount
  of enforcement for a trusted agent.
- **A backstop, because scoping leaves gaps.** The grace and the `touch` bypass are holes
  by design. `graphify-audit.sh` logs any turn that browsed code without a query, so misses
  are surfaced even where a hard block was deliberately not applied. It only records; it
  never blocks the turn.
- **Per turn, not per session.** Consulting the graph once does not buy silence for the
  whole session; the reset hook re-arms the gate on every new user message.

## Install

Run from the Knowledge-Pipeline root (or anywhere; the installer finds its own siblings):

```bash
python hooks/register-hooks.py
```

`register-hooks.py` copies the four scripts into `~/.claude/hooks/` and merges their
registrations into `~/.claude/settings.json`. It is **idempotent** and **additive**: a
registration already present is not duplicated, and unrelated hooks (delegate, ponytail,
etc.) are preserved. Target a different config dir with `CLAUDE_CONFIG_DIR`.

`setup.sh` and `setup.ps1` call this automatically (unless `KP_SKIP_GRAPHIFY=1`).

## Uninstall

Delete the four `graphify-*.sh` from `~/.claude/hooks/` and remove their entries from the
`hooks` block of `~/.claude/settings.json`.
