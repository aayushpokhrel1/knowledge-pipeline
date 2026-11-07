#!/usr/bin/env python3
"""Append a file's contents to a vault note. Paths only, never note text.

    python ~/.claude/bin/vault-note.py <Project> <file> [--note <name>]

This exists because the prose rule ("never put note content on a command line")
was written in three docs and still got violated: a session built a
`wsl -d Ubuntu -- bash -lc 'cat >> ... <<"EOF" ... EOF'` with the note inline,
Windows re-quoted `'...'` to `"..."`, and the backticks in the prose RAN
(`tmux attach` executed; `<name>` parsed as a redirect; an apostrophe ended the
quote). Arbitrary captured text became arbitrary command execution.

So this takes two paths. Paths have no backticks and no apostrophes, the content
is read by Python from the file, and no shell sees it. Do not add a flag that
takes note text: that is the hole this closes.

No WSL. The vault is on the ordinary filesystem, so the host interpreter writes
it directly; WSL is only needed for the claude-obsidian CLI's POSIX metadata.
"""

import argparse
import json
import os
import pathlib
import re
import sys


def vault_dir() -> pathlib.Path:
    """The vault from the env override, else the per-machine config. Never hardcoded."""
    env = os.environ.get("KP_VAULT")
    if env:
        return pathlib.Path(env)
    cfg = pathlib.Path(
        os.environ.get("KP_CLAUDE_DIR") or (pathlib.Path.home() / ".claude")
    ) / "project-scaffold.config.json"
    try:
        vault = json.loads(cfg.read_text(encoding="utf-8")).get("vault")
    except (OSError, ValueError):
        sys.exit(f"vault-note: cannot read {cfg}; run the Knowledge-Pipeline setup")
    if not vault:
        sys.exit(f"vault-note: {cfg} records no vault, so there is nowhere to write")
    return pathlib.Path(vault)


def project_dir(projects: pathlib.Path, name: str) -> pathlib.Path:
    """Resolve <projects>/<name>, reusing a separator/case variant if one exists.

    Chess_Coach ended up with both `Chess-Coach/` and `Chess_Coach/` in the vault
    and its knowledge split in two. A human is meant to spot that; a machine
    actually does.
    """
    exact = projects / name
    if exact.is_dir() or not projects.is_dir():
        return exact
    key = re.sub(r"[-_ ]", "", name).casefold()
    for d in sorted(p for p in projects.iterdir() if p.is_dir()):
        if re.sub(r"[-_ ]", "", d.name).casefold() == key:
            if d.name != name:
                print(f"vault-note: using existing {d.name}/ (you asked for {name})")
            return d
    return exact


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("project", help="project name, matching the repo directory")
    ap.add_argument("file", help="file holding the note text (write it with a file tool)")
    ap.add_argument("--note", default="index", help="note name in the project folder (default: index)")
    args = ap.parse_args()

    src = pathlib.Path(args.file)
    if not src.is_file():
        sys.exit(f"vault-note: no such file: {src}")
    body = src.read_text(encoding="utf-8")

    target = project_dir(vault_dir() / "Projects", args.project) / f"{args.note}.md"
    target.parent.mkdir(parents=True, exist_ok=True)

    existing = target.read_text(encoding="utf-8") if target.exists() else ""
    sep = "" if not existing else ("\n" if existing.endswith("\n") else "\n\n")
    with target.open("a", encoding="utf-8", newline="\n") as f:
        f.write(sep + body.rstrip("\n") + "\n")
    print(f"vault-note: appended {len(body)} chars to {target}")


if __name__ == "__main__":
    main()
