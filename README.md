# Knowledge Pipeline

**An easy, opinionated setup for a local-first knowledge stack: [Obsidian](https://obsidian.md) + [Graphify](https://github.com/Graphify-Labs/graphify) + [claude-obsidian](https://github.com/AgriciDaniel/claude-obsidian).**

One command installs the tools, wires them into Claude Code, and builds a healthy
Obsidian vault, so you can spend your time using them instead of debugging setup
(especially the Windows/WSL permission gotcha that trips most people up).

---

## What you get, and why

These are three independent tools that work well together. Knowledge Pipeline just
sets them up cleanly and explains how they fit.

| Tool | What it is | What it's for |
|------|-----------|---------------|
| **Obsidian** | A note-taking app over plain Markdown files you own (a "vault"), with a graph view of the links between notes. | The **home** for everything you write and want to revisit and interconnect. |
| **claude-obsidian** | A Claude Code plugin + skills that let Claude capture sources, write linked/cited notes, and answer from the vault, all as reviewed, recoverable transactions. | Letting **Claude maintain** that vault so your knowledge compounds instead of restarting every chat. |
| **Graphify** | A local tree-sitter parser that turns a codebase (37 languages, plus docs, PDFs, SQL) into a queryable knowledge graph, exposed as a `/graphify` skill. | **Understanding code you already have**: "what connects auth to the database?" |

**The mental model:**

```
Graphify   →  understands the CODE you have      (per-repo, run graphify .)
Obsidian   →  the HOME for knowledge you keep     (one vault, all projects)
claude-obs →  lets Claude WRITE into that home    (ingest, link, cite, query)
```

Graphify can even export its findings straight into an Obsidian vault (`--obsidian`),
so the two ends meet.

---

## Quick start

### 0. Prerequisites

- **Python 3.10+**
- **Claude Code** (for the `/graphify` and `/claude-obsidian:*` skills)
- A **write-capable platform for the vault**: Linux, macOS, or **WSL on Windows**.
  Native Windows can read a vault but cannot safely write one.
- The **Obsidian desktop app** (free): download from [obsidian.md](https://obsidian.md).
  You install this yourself; the script can't.
- **Windows only, one-time:** enable POSIX metadata on the WSL drive mount so Obsidian
  and the plugin can share a single vault on your Windows drive. See
  [Windows setup](#windows-setup-do-this-once). Do this **before** running `setup.ps1`.

### 1. Run setup

Clone this repo, then run the script for your platform.

**Linux / macOS / WSL** (this also builds the vault):

```bash
git clone https://github.com/aayushpokhrel1/knowledge-pipeline.git
cd knowledge-pipeline
./setup.sh
```

**Windows (PowerShell)** — do the [one-time metadata step](#windows-setup-do-this-once)
first, then:

```powershell
git clone https://github.com/aayushpokhrel1/knowledge-pipeline.git
cd knowledge-pipeline
./setup.ps1
```

The script will:
1. Install [`uv`](https://github.com/astral-sh/uv) if needed and install **Graphify**.
2. Run `graphify install` to add the `/graphify` skill to Claude Code.
3. Clone **claude-obsidian** into `./claude-obsidian/`.
4. Create a vault and verify it (`doctor` reports `ok: true`):
   - **Windows:** at `Documents\Knowledge-Vault` (once metadata is enabled).
   - **Linux/macOS:** at `~/knowledge-vault`.

Everything is idempotent: re-running skips what's already done.

### 2. Open the vault in Obsidian

Obsidian → *Open folder as vault* → select the vault folder:

- **Windows:** `C:\Users\<you>\Documents\Knowledge-Vault`
- **Linux/macOS:** `~/knowledge-vault`

> **Windows: do not open the vault over `\\wsl.localhost\...`.** Obsidian does not
> support vaults on that network share and fails to load with
> `Error EISDIR: illegal operation on a directory`. Keep the vault on your Windows
> drive (the setup above does this) and open it as a normal local folder.

### 3. Use it

**Have Claude maintain the vault** (run from a write-capable shell, i.e. WSL on Windows):

```bash
# Windows (in WSL):
cd /mnt/c/Users/<you>/Documents/Knowledge-Vault
claude --plugin-dir /mnt/c/Users/<you>/dev/.../knowledge-pipeline/claude-obsidian

# Linux/macOS:
cd ~/knowledge-vault
claude --plugin-dir /absolute/path/to/knowledge-pipeline/claude-obsidian
```

Then inside Claude Code:

- `/claude-obsidian:wiki` — orient / see the vault state
- put a file in `inbox/`, then `/claude-obsidian:wiki-ingest` — capture a source into linked, cited notes
- `/claude-obsidian:wiki-query` — ask the vault, grounded in its own evidence
- `/claude-obsidian:wiki-lint` — health-check and tidy

**Map a codebase** (native Windows is fine, no WSL needed):

```bash
graphify .        # or /graphify . inside Claude Code
```

Outputs land in `graphify-out/`: an interactive `graph.html`, a `GRAPH_REPORT.md`,
and a queryable `graph.json`.

---

## Using it day to day

Graphify and Obsidian split cleanly, and it helps to keep the split in mind:

- **Graphify is per repo.** Run `graphify .` in each project; its `graphify-out/` describes
  that codebase and is disposable (gitignore it, regenerate anytime). It answers
  "how does *this* code work?"
- **Obsidian is one vault for everything.** It holds knowledge you write and keep: design
  decisions and their *why*, non-obvious gotchas, research, and cross-project learnings, the
  things that would be lost if you regenerated the code.

Rule of thumb: **if regenerating the code would recreate it, it's Graphify; if it would be
lost, it's Obsidian.**

Organize the vault with one folder per project:

```
Knowledge-Vault/Projects/<name>/index.md    # Key decisions / Gotchas / Research
```

To also park a project's code map in the vault (optional), export the graph into that folder:

```bash
graphify . --obsidian --obsidian-dir "<vault>/Projects/<name>/graph"
```

Point `--obsidian-dir` at a per-project **subfolder**, not the vault root, it writes one
note per node and would otherwise clutter the vault.

### Query-first enforcement (so the graph is actually used)

A knowledge graph that Claude routes around is dead weight. Setup installs four small
Claude Code hooks (into `~/.claude/`) that make "query the graph before browsing raw code"
an enforced rule, not a suggestion:

| Hook | Event | What it does |
|------|-------|--------------|
| `graphify-nudge.sh` | `PreToolUse` (Grep/Glob) | **DENIES** the search in any repo that has a `graphify-out/graph.json`, until a `graphify query`/`path`/`explain` has run **this turn**. |
| `graphify-mark.sh` | `PostToolUse` (Bash) | Records that the graph was consulted when a graphify read command runs, which unblocks Grep/Glob for the rest of the turn. |
| `graphify-reset.sh` | `UserPromptSubmit` | Clears that per-turn marker, so each new question requires a fresh consult. |
| `graphify-banner.sh` | `SessionStart` | Announces the graph and the rule at the top of each session in a repo that has one. |

Notes:
- **Scoped to graph repos only.** In any project without a `graphify-out/graph.json` the
  hooks are silent and never block anything.
- **`Read` is deliberately not hard-denied.** A graph query returns `file:line`; reading
  that line is the intended next step, so blocking `Read` would break the flow the graph
  sets up. `Read` stays a nudge; `Grep`/`Glob` (broad exploration) are the enforced gate.
- **Escape hatch for a genuine exact-string / filename search** (where grep beats the
  graph): `touch` the per-turn marker named in the deny message. It is visible in the
  transcript, so skipping the graph is a conscious, logged act, not a silent default.
- **Idempotent + additive.** Re-running setup preserves any unrelated hooks you already
  have (e.g. delegate or ponytail hooks). The scripts and the shared installer live in
  [`hooks/`](hooks/); install them by hand any time with `python hooks/register-hooks.py`.

---

## Optional: companion Claude skills

The knowledge stack is about *keeping* and *understanding* knowledge. Two more Claude
Code skills round out the *producing* side, so this repo can also set them up for you in
one step. They are independent of the vault and each other; install them only if you want
them.

| Skill | What it is | What it's for | How it fires |
|-------|-----------|---------------|--------------|
| **[humanizer](https://github.com/blader/humanizer)** | A skill (also packaged as a plugin) that rewrites AI-sounding prose using 35 patterns from Wikipedia's "Signs of AI writing," without changing the facts. | Making notes, READMEs, cover letters, and docs read like a person wrote them, not a chatbot. | On demand. Claude invokes it when a task is about editing prose, or you call `/humanizer` explicitly. |
| **[ponytail](https://github.com/DietrichGebert/ponytail)** | A plugin that enforces a "laziest senior dev" ruleset: reuse before writing, stdlib before dependencies, no unrequested abstractions. | Keeping generated code minimal and reviewable, which also means less for you (and any delegated worker) to check. | Automatically. A `SessionStart` hook activates it in every new session at `full` intensity; tune it with `/ponytail [lite\|full\|ultra\|off]`. |

**Why they pair well with a knowledge stack.** A vault compounds only if what lands in it
is clean: humanizer keeps captured prose honest and readable, and ponytail keeps any code
Claude writes small enough that the *why* (which is what belongs in the vault) stays visible
instead of buried under boilerplate.

### Install them

With the setup script (opt-in, since they pull from external repos and need Node and the
Claude CLI):

```bash
# Linux / macOS / WSL
KP_WITH_SKILLS=1 ./setup.sh
```

```powershell
# Windows
$env:KP_WITH_SKILLS = '1'; ./setup.ps1
```

Or by hand:

```bash
npx skills add blader/humanizer --global          # humanizer (restart not needed)
claude plugin marketplace add DietrichGebert/ponytail
claude plugin install ponytail@ponytail           # ponytail (restart Claude Code to load)
```

### Notes worth knowing

- **humanizer is a plain `SKILL.md`** (no hooks, no runtime code beyond a dev-time
  validator), so it is easy to read before you trust it. Its installer's security panel
  shows Socket "Safe / 0 alerts" but Snyk "High Risk"; reading the contents, the Snyk rating
  is a repo-level false positive, not anything the skill executes.
- **This repo ships a local tweak to humanizer:** its em/en-dash rule (§14) is made an
  absolute ban with no writing-sample exception, matching a personal style rule. A
  `npx skills update` overwrites it, so re-apply after updating (the file carries a
  `LOCAL PATCH` marker near the top).
- **ponytail is always on once installed.** If you want it quiet for a session, run
  `/ponytail off`.
- **caveman** ([juliusbrussee/caveman](https://github.com/juliusbrussee/caveman)) was
  evaluated and **not adopted**, for two reasons worth recording. First, on a **Claude
  subscription** (what Claude Code uses by default) its proxy saves nothing: caveman's own
  status reports that "streaming turns and Claude Pro/Max sessions pass through uncompressed,"
  and only non-streaming **API-key** traffic is compressed, so a subscription user gets no
  savings while adding a local proxy as a single point of failure. Second, the proxy
  integration is invasive: `caveman claude` runs `caveman enable claude`, which injects hooks
  into every event in `~/.claude/settings.json` and reroutes `ANTHROPIC_BASE_URL`; on Windows,
  Claude Code runs hooks through bash while caveman writes them in PowerShell syntax, so every
  tool call broke and the session had to be recovered by clearing `hooks` from an external
  editor. The MIT **skill** (`npx skills add JuliusBrussee/caveman`) is harmless if you want
  terse replies, but it compresses *output* (trading against humanizer) and saves no input
  tokens. If you ever run **API-key, non-streaming** workloads the proxy may be worth a careful
  look, with a `settings.json` backup first; for subscription Claude Code use it is not. Not in
  the `KP_WITH_SKILLS` installer.

---

## Optional: design skills (frontend)

The companion skills above cover prose (humanizer) and code restraint (ponytail).
Frontend design is a third producing lane, and Claude Code ships nothing opinionated
for it by default. This is the design set recommended alongside the stack. Unlike the
companion skills, **the setup script does not install these**: they are plain
`SKILL.md` folders you drop into `~/.claude/skills/`, listed here with the reasoning so
the set stays coherent.

The rule that keeps it sane: **one or two generalists, then narrow specialists**, never
a pile of generalists. Three skills that all fire on "design me a landing page" just
compete and hand you conflicting direction.

| Skills | Lane | Role |
|--------|------|------|
| **impeccable** | Generalist | Broad build / redesign / audit / critique: hierarchy, a11y, typography, tokens, motion. |
| **ui-ux-pro-max** | Generalist | UI/UX intelligence plus searchable datasets (styles, palettes, font pairings, UX guidelines, charts, stacks). |
| **animate**, **review-animations**, **improve-animations**, **find-animation-opportunities**, **animation-vocabulary** | Motion | Emil Kowalski's animation craft: build motion, audit it, find where it is missing, name the effect you mean. |
| **apple-design**, **pick-ui-library**, **prototype**, **ask-sonner** | Specialists | Apple-style gesture/spring UI, choosing a library over custom code, multi-version prototyping, Sonner toasts. |

The two generalists were already in place; the nine specialists come from
[emilkowalski/skills](https://github.com/emilkowalski/skills). Animation was the real
gap (neither generalist specializes there), so those add rather than collide.

### Install them (by hand)

They are portable Markdown, so no CLI or config change is involved:

```bash
git clone --depth 1 https://github.com/emilkowalski/skills.git
# copy the folders you want from skills/skills/ into ~/.claude/skills/
cp -r skills/skills/{animate,review-animations,improve-animations,\
find-animation-opportunities,animation-vocabulary,apple-design,\
pick-ui-library,prototype,ask-sonner} ~/.claude/skills/
```

Claude Code picks them up on the next session.

### Not adopted, and why

- **taste-skill** ([leonxlnx/taste-skill](https://github.com/leonxlnx/taste-skill))'s
  flagship `design-taste-frontend`, and Emil's **emil-design-eng**, are both *general*
  design skills. Either one makes a third generalist competing with impeccable and
  ui-ux-pro-max on the same triggers, so both were skipped. taste-skill's dials idea
  (VARIANCE / MOTION / DENSITY) and its hard anti-"AI tell" ban list are worth a look if
  you ever want to *swap out* a generalist rather than stack one on top.
- **animate-expo** (React Native) and **write-swift** (Swift/iOS) are out of scope for
  web work. Skipped, not judged.

---

## Windows setup (do this once)

On Windows the vault should live on your **Windows drive** (so Obsidian opens it as a
normal local folder) while still being written to from **WSL** (which is where the
claude-obsidian plugin runs). For that to work, WSL must expose real file permissions
on the Windows mount, otherwise the plugin's safe-write integrity check fails with
`RESULT_DRIFT` (every file on a default `/mnt/c` mount looks like mode `0777`).

Enable POSIX metadata once:

1. In **PowerShell**, open a root shell in WSL (no password needed):
   ```powershell
   wsl -u root
   ```
2. In that **WSL** shell, write the config and exit:
   ```bash
   printf '[automount]\noptions = "metadata"\n' > /etc/wsl.conf; cat /etc/wsl.conf; exit
   ```
3. Back in **PowerShell**, restart WSL so it remounts with metadata:
   ```powershell
   wsl --shutdown
   ```

Verify (in WSL): `touch /mnt/c/tmp.$$ && chmod 600 /mnt/c/tmp.$$ && stat -c %a /mnt/c/tmp.$$`
should print `600`, not `777`. Then run `setup.ps1`.

**Prefer not to touch `/etc/wsl.conf`?** You can instead keep the vault inside the WSL
filesystem at `~/knowledge-vault` (run `./setup.sh` from within WSL). It needs no system
change, but Obsidian then has to reach it over `\\wsl.localhost\...`, which is
unsupported and error-prone; mapping it to a drive letter (`net use O: \\wsl.localhost\Ubuntu`)
helps but is still second-class. The Windows-drive + metadata route above is smoother.

Two more things worth knowing:
- Vault **writes** are refused on native Windows by design; read-only inspection works anywhere.
- A write's approval hash binds to the environment that produced it, so run the
  dry-run and the apply in the **same** shell.

---

## What the setup installs

- **Graphify** CLI (via `uv tool install graphifyy`) + the `/graphify` Claude skill.
- **uv** (installed via `pip`, or the official installer on systems without pip) to manage Graphify.
- The **[query-first enforcement hooks](#query-first-enforcement-so-the-graph-is-actually-used)**
  into `~/.claude/` (skipped with `KP_SKIP_GRAPHIFY=1`, which the Windows->WSL handoff sets so
  the hooks install once, natively).
- **claude-obsidian** cloned into `./claude-obsidian/` (not vendored into this repo).
- A **vault**, initialized and health-checked.
- **Optional, with `KP_WITH_SKILLS=1`:** the [companion skills](#optional-companion-claude-skills)
  humanizer and ponytail.

No root is required for the tools, and the scripts change no system settings on their
own (the one-time Windows metadata step above is something you run yourself).

---

## Credits

Knowledge Pipeline is just glue and docs. All credit to the underlying projects:

- [Obsidian](https://obsidian.md)
- [Graphify](https://github.com/Graphify-Labs/graphify) (`graphifyy` on PyPI)
- [claude-obsidian](https://github.com/AgriciDaniel/claude-obsidian) by AgriciDaniel (MIT)
- [humanizer](https://github.com/blader/humanizer) by blader (MIT), optional companion skill
- [ponytail](https://github.com/DietrichGebert/ponytail) by Dietrich Gebert (MIT), optional companion plugin
- [emilkowalski/skills](https://github.com/emilkowalski/skills) by Emil Kowalski (MIT), optional design/animation skills

## License

This project is licensed under the MIT License — see [LICENSE](LICENSE) for details.

MIT is a permissive open-source license that allows you to:
- ✅ Use this software for personal, commercial, and private purposes
- ✅ Modify and distribute the software
- ✅ Include it in proprietary applications

With just one requirement: include a copy of the license and copyright notice.

**Copyright © 2026 Aayush Pokhrel**
