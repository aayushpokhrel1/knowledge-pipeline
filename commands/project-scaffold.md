---
description: Create this project's standard doc structure (README / PRODUCT / DESIGN / CLAUDE / HANDOVER, docs/OPERATIONS.md, specs and plans homes), the gitignore lines, the handover budget test, and the vault folder
argument-hint: "[path to the repo (optional, defaults to the current directory)]"
---

Run the `project-scaffold` skill against `$ARGUMENTS`, or the current directory when no path
is given.

Follow the skill exactly; it is the spec. The parts most often skipped, so worth repeating
here:

- **Step 0 first.** Resolve the vault path, whether WSL is needed, and the repo path for this
  machine, from `~/.claude/project-scaffold.config.json` or by probing. Nothing is hardcoded,
  and a wrong vault path splits the knowledge in two.
- **Check it is one repo** before treating a directory as the project. A folder under the
  projects directory can hold several sibling repos, each with its own remote.
- **A missing file is not automatically a gap.** Grep the existing docs for a negative
  declaration ("There is no `HANDOVER.md` here", "deliberately no `DESIGN.md`") and honour it,
  along with everything downstream of it.
- **Never overwrite.** Report an existing file as present and move on.
- **Interview, then fill.** Real content from the user's answers, never placeholder stubs, and
  never an invented PRODUCT.md decision.

If the path given is not a git repository, say so and ask before scaffolding it anyway.
