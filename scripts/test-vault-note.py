#!/usr/bin/env python3
"""Self-check for scripts/vault-note.py. Run: python scripts/test-vault-note.py

The case that matters is the first one: note text full of shell metacharacters
must survive byte for byte, because that text is what the old
wsl + heredoc route executed.
"""

import os
import pathlib
import subprocess
import sys
import tempfile

HERE = pathlib.Path(__file__).resolve().parent
TOOL = HERE / "vault-note.py"

HOSTILE = "A note with `tmux attach`, a <name> redirect, tmux's apostrophe and $(id).\n"


def run(vault, *args):
    r = subprocess.run(
        [sys.executable, str(TOOL), *args],
        env={**os.environ, "KP_VAULT": str(vault)},
        capture_output=True,
        text=True,
    )
    assert r.returncode == 0, f"vault-note failed: {r.stderr}"
    return r.stdout


def main():
    with tempfile.TemporaryDirectory() as tmp:
        tmp = pathlib.Path(tmp)
        vault = tmp / "vault"
        src = tmp / "note.md"
        src.write_text(HOSTILE, encoding="utf-8")

        # 1. Hostile content arrives verbatim, and nothing ran.
        run(vault, "Demo", str(src))
        got = (vault / "Projects" / "Demo" / "index.md").read_text(encoding="utf-8")
        assert got == HOSTILE, repr(got)

        # 2. A second append is separated by a blank line, not glued on.
        run(vault, "Demo", str(src))
        got = (vault / "Projects" / "Demo" / "index.md").read_text(encoding="utf-8")
        assert got == HOSTILE + "\n" + HOSTILE, repr(got)

        # 3. A separator/case variant is reused, not duplicated.
        (vault / "Projects" / "Demo-Project").mkdir()
        out = run(vault, "demo_project", str(src))
        assert "using existing Demo-Project" in out, out
        assert not (vault / "Projects" / "demo_project").exists(), "made a duplicate folder"

        # 4. --note writes a sibling note, not the index.
        run(vault, "Demo", str(src), "--note", "gotcha-wsl-quoting")
        assert (vault / "Projects" / "Demo" / "gotcha-wsl-quoting.md").is_file()

    print("test-vault-note: ok")


if __name__ == "__main__":
    main()
