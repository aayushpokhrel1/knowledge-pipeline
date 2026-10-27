# Working in this repo

An opinionated setup for a local-first knowledge stack: Obsidian + Graphify + claude-obsidian.

## Where things are written down

| File | What it holds |
| --- | --- |
| `README.md` | What you get, why, and the quick start |
| `hooks/` | Claude Code hooks registered by the setup scripts |
| `skills/project-scaffold/` | The `/project-scaffold` skill: creates a new project's doc structure, guards and vault folder. Installed into `~/.claude/skills/` by the setup scripts as a USER-LEVEL skill, linked at this repo so a `git pull` updates it in place |
| `commands/project-scaffold.md` | The slash command that invokes that skill. Installed into `~/.claude/commands/` the same way |
| `claude-obsidian/` | A VENDORED CLONE of a third-party repo. Do not restructure it or add docs to it |

**Nothing in `skills/` may hardcode a path.** It runs on more than one machine, so the vault
location, whether vault writes need WSL, and the WSL distro are resolved at runtime and cached
in `~/.claude/project-scaffold.config.json`, which the setup scripts seed because they have
already worked the vault out. A hardcoded `C:\Users\<name>\...` is a bug, not a detail.

**It is a user-level skill, not a plugin, on purpose.** Packaging it as a plugin would list it
a second time under a plugin namespace beside the user-level copy, and the two would collide.

This repo's job is **setup**, so its README is the product. It installs the vault tooling that the rule below depends on.

## When Aayush says "update"

"Update the docs", "update everything", or just "update" means **all of it, in this turn**:

1. **The knowledge vault** - `C:\Users\aayus\Documents\Knowledge-Vault\Projects\Knowledge-Pipeline\`
   (the path is per-machine). Add what this session learned that is worth keeping: a decision and
   its WHY, a non-obvious gotcha or fix, a research finding, a cross-project learning. This is the
   part that gets forgotten, and it is the part that compounds.
2. **Every doc in this repo**, not only the one already open.
3. **The handover**, but only its current-state numbers.

**Vault writes go through WSL, and note content must never appear on the command line.** The Bash
tool re-quotes the wrapper, so backticks and apostrophes inside a note get executed or break the
command. Write the note to a file first, then pass only literal paths:

```
wsl -d Ubuntu -- bash -lc 'cat /mnt/c/<tmp>/note.md >> /mnt/c/Users/aayus/Documents/Knowledge-Vault/Projects/Knowledge-Pipeline/index.md'
```

**Updating docs means making them TRUE, not just appending what shipped.** Correct or strike a
stale claim where it sits rather than adding a newer entry underneath it, because the next reader
may hit the old one first. Cross-check every number (versions, counts, commit) against reality
instead of trusting what the file says.

## Where knowledge goes

A lesson has exactly one home, chosen by how far it reaches:

- **A rule about specific code goes in a comment AT that code.** The most reliable form there is:
  you cannot edit the function without reading the warning above it. A note filed elsewhere is the
  least reliable, because nobody goes back to read it.
- **A lesson that generalises goes in the vault**, phrased so it is useful on a different
  project, with this one as the example.
- **A dated narrative of what you did today goes in `git log`.** It is already there, in detail.

Keep any one lesson in a single place. Two copies drift, and the drift is what causes wrong work
later.
