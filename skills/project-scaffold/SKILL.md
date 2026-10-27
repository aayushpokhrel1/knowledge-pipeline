---
name: project-scaffold
description: "Set up Aayush's standard project doc structure in a repo: README / PRODUCT / DESIGN / CLAUDE / HANDOVER, docs/OPERATIONS.md, docs/superpowers/{specs,plans}/, the gitignore lines, the handover budget test, the graph, and the Obsidian vault folder. Use when starting a new project, or when an existing repo is missing its docs. Trigger: /project-scaffold, \"scaffold the docs\", \"set up this project\", \"this repo has no docs\"."
---

# /project-scaffold

Create the file structure every one of Aayush's projects converges on, filled with real
content rather than stubs, plus the mechanical guards that keep it from rotting.

Works on a new repo and on an existing one. **Never overwrite a file that already exists**
(report it as present and move on); only create the gaps.

**A missing file is not automatically a gap.** Before creating anything, grep the existing
`CLAUDE.md` / `README.md` for a negative declaration about it: "There is no `HANDOVER.md`
here", "There is deliberately **no** `DESIGN.md`", "Do not create a `LESSONS.md`". Those
are decisions, and creating the file anyway puts the repo in contradiction with its own
routing table. Report it as *deliberately absent* and skip it, along with everything
downstream of it (no `HANDOVER.md` means no gitignore line and no budget test).
`budgerr-app` and `budgerr-web` both declare this; the first run of this skill would have
overridden both.

**First, check it is one repo.** A directory under `dev/Projects/` can be a container for
several sibling repos (`Budgerr/` holds three, each with its own GitHub remote). Run
`git -C <sub> remote -v` on each subdirectory before treating the parent as the project.
Scaffold one repo per run and say which; a container gets no docs of its own.

## Why this exists, in one line

Nine projects independently arrived at the same routing table because the alternative
(everything in `HANDOVER.md`) reached 1,365 lines on FamilyRecipes and started contradicting
itself, which caused real wrong work. The table is the fix, and the tests are what make the
table stick.

---

## Step 0: resolve this machine (nothing here is hardcoded)

This skill runs on more than one computer, so **never assume a path**. Three things differ
per machine: where the vault is, whether vault writes need WSL, and what the projects
directory is called. Resolve all three before Step 5 needs them.

Read the cache first. If `~/.claude/project-scaffold.config.json` exists, use it and skip
the probing:

```bash
cat ~/.claude/project-scaffold.config.json 2>/dev/null
```

It holds exactly this, and nothing secret:

```json
{ "vault": "C:/Users/you/Documents/Knowledge-Vault", "wsl": true, "wslDistro": "Ubuntu" }
```

**Write a Windows path with FORWARD slashes, and never hand-build this file with `printf`.**
`"C:\Users\..."` is not valid JSON, because `\U` is not a legal escape, so the cache fails
to parse on the next run and the skill silently falls back to probing. Confirmed on
2026-10-26, when the first hand-written cache was invalid. Dump it with `json.dump` (or
PowerShell's `ConvertTo-Json`, which escapes correctly), and if it fails to parse, say so
and re-probe rather than editing around it.

If it does not exist, work it out:

```bash
uname -s                                    # MINGW*/MSYS* = Windows, Darwin = mac, Linux = linux
echo "$KNOWLEDGE_VAULT"                     # an explicit override always wins
ls -d ~/Documents/Knowledge-Vault ~/Knowledge-Vault ~/vault 2>/dev/null
ls -d ~/Documents/*Vault* 2>/dev/null        # last resort, catches a renamed vault
```

- **The `KNOWLEDGE_VAULT` environment variable wins** whenever it is set. That is the escape
  hatch for a vault somewhere unusual, and the thing to tell the user about if probing fails.
- **Found exactly one candidate** → use it.
- **Found none, or more than one** → ask the user once with `AskUserQuestion`, offering what
  you found. Do not guess between two vaults; picking wrong splits their knowledge in two,
  which is the `Chess-Coach` / `Chess_Coach` failure in a worse form.
- **The user says there is no vault** → write `{"vault": null}` and skip Step 5 on every run,
  saying so in one line. The repo files are still worth creating.

Then **write the answer to the cache** so no later run asks again.

### Whether vault writes need WSL

Only Windows needs the WSL dance, and only because of how this toolchain quotes arguments:

- **macOS / Linux**: write to the vault directly. No WSL, no wrapper, nothing from Step 5's
  Windows notes applies. Skip straight to the content.
- **Windows**: go through WSL as Step 5 describes. Get the distro from `wsl -l -q` rather
  than assuming `Ubuntu`, and cache it. **Skip the entries that are not real distros**:
  `docker-desktop` and `docker-desktop-data` appear in that list and have no user home, so
  taking the first line blindly can pick one. Prefer the first remaining entry, and ask if
  more than one is left. If `wsl -l -q` fails or returns nothing, there is no WSL: fall back
  to writing the vault file with your own file tools, or with `python` against the Windows
  path, and say which you did.

Record the result as `wsl` and `wslDistro` in the cache.

### The projects directory

Never write a `dev/Projects/<Name>` path from memory. The repo being scaffolded is the
current directory, so derive it:

```bash
git rev-parse --show-toplevel 2>/dev/null || pwd
```

That string is what goes in the vault note's `Repo:` line, verbatim.

## Step 1: read the repo before asking anything

Run these, don't ask the user what they could have told you:

```bash
ls -1
cat package.json 2>/dev/null | head -40
ls -1 pyproject.toml requirements.txt Cargo.toml go.mod CMakeLists.txt 2>/dev/null
git remote -v 2>/dev/null
git log --oneline -5 2>/dev/null
cat .gitignore 2>/dev/null
```

From that you already know: the stack, the test runner, whether it's a git repo, whether
the remote is public, and what docs exist. Then report in one short block what's present
and what's missing, so the user sees the gap before answering questions.

## Step 2: the interview (only what you can't read)

Ask these as ONE `AskUserQuestion` call, dropping any you already know from Step 1:

1. **What is it, in one or two sentences?** (fills README's opening and the vault index)
2. **Who is it for, and what is deliberately NOT in scope?** (fills PRODUCT.md; the
   "deferred **and why**" half is the part that stops a later session re-proposing a thing
   already tried and rejected)
3. **Is there a UI?** → decides whether `DESIGN.md` exists at all. If no UI, say so
   explicitly in CLAUDE.md ("There is deliberately no `DESIGN.md`: there is no UI"), the way
   whereami does, so a later session doesn't create one.
4. **Public repo?** → if public, `PRODUCT.md` and `docs/superpowers/plans/` get gitignored
   and their canonical copy lives in the vault. Specs stay tracked either way: a spec
   explains why the code is shaped as it is.
5. **Does it need `docs/ARCHITECTURE.md` and/or `docs/FINDINGS.md`?** Only create these
   when there's something to put in them today. ARCHITECTURE for a multi-service system or
   a real data model; FINDINGS when the project measures something and the measurements
   need to rule things out. Don't create empty ones.

Do not ask about the vault, the gitignore lines, the budget test, or the graph. Those are
decided: they always happen.

## Step 3: write the files

Create only what's missing. Every file gets real content from the interview, never a
placeholder the user has to come back and fill.

| File | Tracked? | What it holds |
| --- | --- | --- |
| `README.md` | yes | What it is, what it does, the stack, how to run it, links to the rest. On a public repo this is the product |
| `PRODUCT.md` | yes, unless public | Product truth: who it is for, decisions, roadmap, what is deferred **and why** |
| `DESIGN.md` | yes, if UI | The visual system: tokens, type, colour, component patterns |
| `CLAUDE.md` | yes | The routing table below, plus this project's own rules. Auto-loaded every session, survives a fresh clone |
| `HANDOVER.md` | **gitignored** | **Only** current state: head commit, deployed versions, test count, what is half-done, what is next |
| `docs/OPERATIONS.md` | yes | Run, verify, CI, deploy, secrets, monitoring, environment traps, latent landmines |
| `docs/ARCHITECTURE.md` | yes, if asked for | How the system is put together, and the data model |
| `docs/FINDINGS.md` | yes, if asked for | What has been measured, and what it rules out |
| `docs/superpowers/specs/` | yes | The design of one feature, written before building it. `YYYY-MM-DD-<feature>.md` |
| `docs/superpowers/plans/` | yes, unless public | The task breakdown for one feature. Same naming |

Create the two `docs/superpowers/` directories with a `.gitkeep` each so they survive a
clone empty.

### The CLAUDE.md to write

This is the important file: it's the only one auto-loaded every session. Write it with
**only the rows this project actually has** (don't list `DESIGN.md` on a CLI tool), and
include these four sections verbatim in substance:

1. **`## Where things are written down`** — the routing table above, trimmed to this
   project, with these three non-file rows appended:

   | a **code comment at the site** | A rule about specific code |
   | the **Obsidian vault** | A lesson that would change how I work on a *different* project |
   | nowhere | A dated narrative of what you did today. `git log` already holds it, in more detail |

2. **`## The handover`** — that it is gitignored and local-only, so nothing durable may
   live there, and the test: *before adding a line, ask whether it will still be true in a
   month. If yes it belongs in a permanent doc or the vault.* Name the 1,365-line
   FamilyRecipes failure as the reason, in one sentence.

3. **`## Where knowledge goes`** — lessons have ONE home each, by reach:
   a rule about specific code → a comment AT that code (the most reliable form by a
   distance: you cannot edit the function without reading the warning above it);
   a lesson that generalises → the vault, phrased so it's useful on another project with
   this one as the example; neither → it wasn't a lesson. **Do not create a `LESSONS.md`**
   (tried on FamilyRecipes 2026-09-27, deleted the same day: every entry was a third copy).
   And: prefer a mechanical defence (a failing test, a CI job, a grep, an unavoidable
   comment) over a written one. The failure mode is not ignorance, it's not re-reading.

4. **`## When Aayush says "update"`** — "update the docs" / "update everything" / "update"
   means all of it in this turn: the vault folder first (the part that gets forgotten and
   the part that compounds), then every doc in the repo, then the handover's current-state
   numbers only. Write this project's vault path into that section as a REAL path, resolved
   in Step 0, not a placeholder: the generated CLAUDE.md is read on one machine and a
   `<vault>` token in it is useless. On Windows, include the WSL warning too, using the
   resolved distro:

   ```
   MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' wsl -d <distro> -- bash /mnt/<drive>/<tmp>/vault-write.sh
   ```

   and the reason: the Bash tool re-quotes the wrapper, so backticks and apostrophes inside
   a note get executed or break the command. Write the note to a file first, pass only
   literal paths. And: **updating docs means making them TRUE, not just appending what
   shipped** — correct or strike a stale claim where it sits, and cross-check every number
   against reality rather than trusting the file.

5. **`## Project rules`** — start it with whatever the interview surfaced (the verify
   command at minimum, e.g. "**Verify with `npx tsc -b && npm test`**"), and leave it to
   grow. One bullet is fine; an empty section is not.

## Step 4: the mechanical guards

### 4a. gitignore

Append if missing (with the reason as a comment, since a bare filename looks like a
mistake to the next reader):

```
# Session handover (local-only, this machine): current state only, nothing durable
HANDOVER.md

# Knowledge graph cache (rebuilt by the graphify post-commit hook)
graphify-out/
```

Plus, on a public repo, `PRODUCT.md` and `docs/superpowers/plans/`, with a comment saying
the canonical copy is in the vault.

### 4b. the handover budget test

A doc asking for brevity does not get it. Write the smallest test the project's existing
runner will pick up, failing when `HANDOVER.md` exceeds 200 lines or grows dated section
headings. **The answer when it goes red is to MOVE content to its home, never to raise the
budget** — put that sentence in the test as a comment, because the test is where someone
will be standing when they're tempted.

Detect the runner from Step 1. If the project has no test runner at all, skip this and say
so in one line; don't install a framework for one check.

Vitest / Jest (`handover.budget.test.ts`, beside the other tests):

```ts
// Fails when HANDOVER.md accumulates. The fix is ALWAYS to move content to its real home
// (README / PRODUCT / docs/OPERATIONS / the vault), never to raise MAX.
import { readFileSync, existsSync } from 'node:fs'
import { test, expect } from 'vitest'

const MAX = 200

test('HANDOVER.md stays a current-state note', () => {
  if (!existsSync('HANDOVER.md')) return
  const lines = readFileSync('HANDOVER.md', 'utf8').split('\n')
  expect(lines.length).toBeLessThanOrEqual(MAX)
  const dated = lines.filter(l => /^#{1,4} .*\d{4}-\d{2}-\d{2}/.test(l))
  expect(dated, 'dated headings belong in git log, not the handover').toEqual([])
})
```

pytest (`tests/test_handover_budget.py`):

```python
# Fails when HANDOVER.md accumulates. The fix is ALWAYS to move content to its real home
# (README / PRODUCT / docs/OPERATIONS / the vault), never to raise MAX.
import re
from pathlib import Path

MAX = 200


def test_handover_stays_a_current_state_note():
    p = Path("HANDOVER.md")
    if not p.exists():
        return
    lines = p.read_text(encoding="utf-8").splitlines()
    assert len(lines) <= MAX, f"HANDOVER.md is {len(lines)} lines; move content, do not raise MAX"
    dated = [l for l in lines if re.match(r"^#{1,4} .*\d{4}-\d{2}-\d{2}", l)]
    assert not dated, f"dated headings belong in git log: {dated}"
```

Run it once and confirm it passes. If it fails, the handover already needs a sweep: say so.

### 4c. the graph and the hook

```bash
graphify .
git config --get core.hooksPath
```

If `core.hooksPath` isn't set to `~/.config/git/hooks`, say so in one line and leave it:
it's a user-global setting and changing it affects every repo, so that's the user's call.

Then add the graphify stanza to CLAUDE.md: query / path / explain before grep.

**`graphify .` writes the graph but NOT `GRAPH_REPORT.md`.** The report needs a separate
`graphify cluster-only .` and another model call, so do not copy a sibling project's stanza
promising a report this repo has not generated; that is a stale claim on arrival. Either run
`cluster-only` too, or say in the stanza that there is no report and the graph alone is
enough for query/path/explain. Confirmed on 2026-10-26.

The first `graphify .` also **costs a model call** (it reported ~$0.014 and ~21k tokens on a
small repo), unlike the post-commit hook, which is AST-only and free. Expect warnings about
files that produced no nodes; a re-run retries them and costs again, so only re-run if the
graph is actually unusable.

## Step 5: the vault folder

`<vault>/Projects/<Name>/index.md`, where `<vault>` is what Step 0 resolved and `<Name>`
matches the repo directory name exactly. Check for a near-miss first (Chess_Coach had both
`Chess-Coach/` and `Chess_Coach/` in the vault, which split its knowledge in two); if one
exists, use it and say so rather than creating a second. Skip this whole step when Step 0
recorded `"vault": null`.

Write the note to a scratchpad file with the Write tool first, whatever the platform.
**Never put note content on the command line.** That is the only rule that always holds;
everything else here is about which interpreter runs your script.

**Writing a plain Markdown note does NOT need WSL, even on Windows.** The vault sits on the
ordinary filesystem, so the host `python` writes it directly. WSL is needed for the
`claude-obsidian` CLI, which wants POSIX metadata, not for appending to or editing a note.
Reaching for WSL anyway adds three failure modes for no benefit, all three hit on
2026-10-26: a distro to resolve, argument paths to translate, and a service that can simply
be down (`Wsl/Service/0x80072747`). **So default to the host interpreter with native paths**,
and go through WSL only for a `claude-obsidian` command.

**A script's paths must match the interpreter that runs it.** A script holding
`C:\Users\...` run under WSL dies with `FileNotFoundError`, because WSL needs
`/mnt/c/Users/...`. Pick one form and keep the whole script in it. This is the mistake to
expect, and it is why the host interpreter is the simpler default.

**If you do use WSL, two more things break it**, both confirmed on 2026-10-21. Write a
script FILE and run that; never build a `bash -lc '...'` one-liner.

1. **The Bash tool re-quotes the wrapper, so `$VAR` and backslash-escapes inside
   `bash -lc '...'` are mangled.** A `V=/mnt/c/...` assignment followed by `"$V/index.md"`
   arrived as the literal path `/index.md`, and every write failed to open its file. It
   failed loudly that time; a pattern that half-expands can corrupt a note instead.
2. **Git Bash rewrites `/mnt/...` arguments into Windows paths.** Passing the script path
   straight to `wsl` produced
   `bash: C:/Program Files/Git/mnt/c/.../script.sh: No such file or directory`.
   Prefix the call with `MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*'`.

So:

```bash
# after writing the script to the scratchpad with the Write tool.
# <distro> is from Step 0 (wsl -l -q), never assumed.
MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' wsl -d <distro> -- bash /mnt/<drive>/<scratchpad>/vault-write.sh
```

**If WSL itself fails, that is not a dead end.** It returned
`Wsl/Service/0x80072747` (a socket buffer error) mid-session once. The vault is on the normal
filesystem, so fall back to running the same script with the host `python` against the native
path. The rule being protected is only ever *note content must not touch the command line*,
and a script file satisfies it either way.

and the script itself does the `mkdir -p` and `cp`, with the paths written inside it. For
any edit to an EXISTING note, have that script call `python3` with a heredoc rather than
`sed`: a wikilink is full of `[`, `|` and `\` that sed treats as syntax, and a `python3 -`
heredoc also lets you assert you matched exactly one line before rewriting it, so a missed
match fails instead of silently doing nothing.

The shape, matching the existing vault notes:

```markdown
---
type: index
title: <Name>
status: evergreen
created: <today>
updated: <today>
tags:
  - index
  - projects
---

# <Name>

<the one-or-two-sentence description from the interview, with the stack in parentheses>

- Repo: `<the git rev-parse --show-toplevel path from Step 0>`
- Docs: `README.md`, `PRODUCT.md`, `docs/OPERATIONS.md`<, the rest>
- Related: <[[Projects/Other/index|Other]] where there's a real relationship>

## Key decisions

## Gotchas

## Research
```

Leave the three sections empty with their headings: they're the homes, and a fabricated
first entry is worse than none. Then add one line to the vault's `Projects/index.md` under
"Active projects", in the same `[[Projects/<Name>/index|<Name>]] - <hook>` form, via the
same write-a-file-then-WSL route.

## Step 6: report

One short block: what was created, what was already present and skipped, what was
deliberately not created and why (no `DESIGN.md`, no ARCHITECTURE, no budget test), and
whether the budget test and the graph ran clean. Then stop. Don't offer to fill the docs
in the same turn: the user writes PRODUCT truth, not you.

---

## What this skill does NOT do

- **It doesn't write a `LESSONS.md`.** Ever. See Step 3 §3.
- **It doesn't fabricate PRODUCT.md decisions.** The interview answers go in; invented
  roadmap items become stale claims the next session acts on.
- **It doesn't overwrite.** A repo with a 400-line CLAUDE.md gets its gaps filled and that
  file left alone, with a one-line note if the routing table is missing from it.
- **It doesn't install a test framework** to host the budget test.
- **It doesn't touch `core.hooksPath`.** User-global, user's call.
