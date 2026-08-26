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
  Native Windows can read a vault but cannot safely write one (see [Why WSL](#why-the-vault-lives-in-wsl-on-windows)).
- The **Obsidian desktop app** (free): download from [obsidian.md](https://obsidian.md).
  You install this yourself; the script can't.

### 1. Run setup

Clone this repo, then run the script for your platform.

**Linux / macOS / WSL** (this also builds the vault):

```bash
git clone https://github.com/aayushpokhrel1/knowledge-pipeline.git
cd knowledge-pipeline
./setup.sh
```

**Windows (PowerShell)** — installs the Graphify half natively, then hands the
vault step to WSL:

```powershell
git clone https://github.com/aayushpokhrel1/knowledge-pipeline.git
cd knowledge-pipeline
./setup.ps1
```

The script will:
1. Install [`uv`](https://github.com/astral-sh/uv) if needed and install **Graphify**.
2. Run `graphify install` to add the `/graphify` skill to Claude Code.
3. Clone **claude-obsidian** into `./claude-obsidian/`.
4. Create a vault at `~/knowledge-vault` (override with `VAULT_DIR=...`) and verify it.

Everything is idempotent: re-running skips what's already done.

### 2. Open the vault in Obsidian

- **Linux/macOS:** Obsidian → *Open folder as vault* → `~/knowledge-vault`
- **Windows (vault is in WSL):** Obsidian → *Open folder as vault* → paste
  `\\wsl.localhost\<Distro>\home\<you>\knowledge-vault`
  (e.g. `\\wsl.localhost\Ubuntu\home\yourname\knowledge-vault`)

### 3. Use it

**Have Claude maintain the vault** (run from a write-capable shell, i.e. WSL on Windows):

```bash
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

## Why the vault lives in WSL on Windows

claude-obsidian protects your vault with safe-write transactions that depend on
real POSIX file permissions. The Windows `/mnt/c` mount reports every file as mode
`0777`, so the plugin's integrity check fails with `RESULT_DRIFT` even though the
file contents are correct.

The clean fix (and the plugin authors' own recommendation) is to keep the vault on
the **WSL filesystem** (`~/knowledge-vault`), which has native permissions. It's
still fully visible from Windows Explorer and Obsidian at
`\\wsl.localhost\<Distro>\home\<you>\knowledge-vault`. The alternative, enabling
`metadata` on the `/mnt/c` automount in `/etc/wsl.conf`, is a system-level change
this project deliberately does not make for you.

Two more things worth knowing:
- Vault **writes** are refused on native Windows by design; read-only inspection works anywhere.
- A write's approval hash binds to the environment that produced it, so run the
  dry-run and the apply in the **same** shell.

---

## What the setup installs

- **Graphify** CLI (via `uv tool install graphifyy`) + the `/graphify` Claude skill.
- **uv** (installed via `pip` if you don't already have it) to manage Graphify.
- **claude-obsidian** cloned into `./claude-obsidian/` (not vendored into this repo).
- A **vault** at `~/knowledge-vault`, initialized and health-checked.

Nothing requires root, and no system settings are changed.

---

## Credits

Knowledge Pipeline is just glue and docs. All credit to the underlying projects:

- [Obsidian](https://obsidian.md)
- [Graphify](https://github.com/Graphify-Labs/graphify) (`graphifyy` on PyPI)
- [claude-obsidian](https://github.com/AgriciDaniel/claude-obsidian) by AgriciDaniel (MIT)

## License

MIT — see [LICENSE](LICENSE).
