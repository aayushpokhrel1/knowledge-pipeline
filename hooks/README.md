# Graphify query-first hooks

Four small Claude Code hooks that make **"query the knowledge graph before browsing
raw code"** an enforced rule instead of a suggestion. They fire **only** in a repo that
has a `graphify-out/graph.json`; everywhere else they are silent and block nothing.

## Why

A graph Claude routes around is dead weight. A `SessionStart` banner and a per-Grep
reminder are easy to read and ignore. These hooks add teeth: broad code exploration is
**denied** until the graph has actually been consulted.

## The scripts

| Script | Event | Behaviour |
|--------|-------|-----------|
| `graphify-nudge.sh` | `PreToolUse` (Grep\|Glob) | If the repo has a graph and no consult has happened **this turn**, return a `deny` decision telling Claude to run `graphify query`/`path`/`explain` first. |
| `graphify-mark.sh` | `PostToolUse` (Bash) | If the command that ran was `graphify query|path|explain|god-nodes|affected|read`, write the per-turn marker, which unblocks Grep/Glob for the rest of the turn. |
| `graphify-reset.sh` | `UserPromptSubmit` | New turn → delete the marker, so each question needs a fresh consult. |
| `graphify-banner.sh` | `SessionStart` | Announce the graph and the enforced rule. |

The per-turn marker is `~/.claude/state/graphify-ok.<hash-of-project-dir>`.

## Design choices (deliberate, not omissions)

- **`Read` is not hard-denied.** A graph query returns `file:line`; reading that line is
  the intended next step. Denying `Read` would break the very flow the graph sets up, so
  `Read` stays a nudge and `Grep`/`Glob` (broad search) are the enforced gate.
- **A hook cannot read intent.** It cannot tell a code-question grep from a legitimate
  exact-string search. So there is an escape hatch: `touch` the marker named in the deny
  message. Because that shows up in the transcript, skipping the graph becomes a conscious,
  logged act, which is the right amount of enforcement for a trusted agent.
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
