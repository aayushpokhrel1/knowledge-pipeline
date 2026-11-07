# Working in this repo

An opinionated setup for a local-first knowledge stack: Obsidian + Graphify + claude-obsidian.

## Where things are written down

| File | What it holds |
| --- | --- |
| `README.md` | What you get, why, and the quick start |
| `hooks/` | The six graphify query-first hooks, registered by the setup scripts. `hooks/README.md` is the home for how the gate is scoped and why |
| `skills/project-scaffold/` | The `/project-scaffold` skill: creates a new project's doc structure, guards and vault folder. Installed into `~/.claude/skills/` by the setup scripts as a USER-LEVEL skill, linked at this repo so a `git pull` updates it in place |
| `commands/project-scaffold.md` | The slash command that invokes that skill. Installed into `~/.claude/commands/` the same way |
| `scripts/install-scaffold.{sh,ps1}` | The installer itself, sourced by the matching setup script. **Sourcing must stay side-effect free**: it defines functions only, so CI and the tests can point it at a sandbox and assert on the result |
| `scripts/vault-note.py` | The vault append, installed to `~/.claude/bin/`. Takes **paths only**, by design: note text on a command line gets its backticks executed. Do not add a flag that takes text |
| `scripts/test-vault-note.py` | Self-check for it. The first case appends prose full of backticks, `<name>` and apostrophes and asserts it survives byte for byte |
| `scripts/test-install-scaffold.{sh,ps1}` | Smoke tests that run the real installer into a throwaway directory. Run them before touching either installer |
| `scripts/check-skills.sh` | Holds `skills/` to the rules stated below, and fails when a `hooks/graphify-*.sh` is missing from the installer or from either doc table, so they are not merely written down |
| `.github/workflows/ci.yml` | Runs all of the above on Linux, and on Windows under both PowerShell and Git Bash |
| `claude-obsidian/` | A third-party repo that setup clones here. It is gitignored, NOT vendored. Do not restructure it or add docs to it |

**Verify with `bash scripts/check-skills.sh && bash scripts/test-install-scaffold.sh && python scripts/test-vault-note.py`**, plus
`./scripts/test-install-scaffold.ps1` when the Windows installer changed (it passes under both
Windows PowerShell 5.1 and `pwsh`; CI uses `pwsh`, which is not on every machine). CI runs all
three. There is deliberately **no shellcheck step**: it has not been watched go green here, and
a gate nobody has seen pass is how a default branch ends up red. Add it once it does.

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

**Note content must never appear on a command line.** Write the note to a file, then append it
with the installed tool, which takes paths only and needs no WSL:

```bash
python ~/.claude/bin/vault-note.py Knowledge-Pipeline <scratchpad>/note.md
```

A shell executes the backticks in prose, and a heredoc does not save you, because the wrapper is
re-quoted on the way across. README's "Windows setup" section has the full post-mortem.

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
