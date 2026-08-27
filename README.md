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
- **claude-obsidian** cloned into `./claude-obsidian/` (not vendored into this repo).
- A **vault**, initialized and health-checked.

No root is required for the tools, and the scripts change no system settings on their
own (the one-time Windows metadata step above is something you run yourself).

---

## Credits

Knowledge Pipeline is just glue and docs. All credit to the underlying projects:

- [Obsidian](https://obsidian.md)
- [Graphify](https://github.com/Graphify-Labs/graphify) (`graphifyy` on PyPI)
- [claude-obsidian](https://github.com/AgriciDaniel/claude-obsidian) by AgriciDaniel (MIT)

## License

This project is licensed under the MIT License — see [LICENSE](LICENSE) for details.

MIT is a permissive open-source license that allows you to:
- ✅ Use this software for personal, commercial, and private purposes
- ✅ Modify and distribute the software
- ✅ Include it in proprietary applications

With just one requirement: include a copy of the license and copyright notice.

**Copyright © 2026 Aayush Pokhrel**
