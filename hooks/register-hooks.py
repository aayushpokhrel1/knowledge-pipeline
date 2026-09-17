#!/usr/bin/env python3
"""Install the graphify query-first hooks into a Claude Code config dir.

Copies the graphify-*.sh scripts sitting next to this file into <config>/hooks/
and merges their registrations into <config>/settings.json, idempotently. Safe to
re-run: existing, unrelated hooks (e.g. the delegate hooks) are preserved, and a
graphify entry already present is not duplicated.

Config dir resolution: $CLAUDE_CONFIG_DIR if set, else ~/.claude. Cross-platform:
called by both setup.sh (Linux/macOS/WSL) and setup.ps1 (native Windows), so the
same JSON-merge logic lives in one place instead of being written twice.

The hooks fire only in projects that have a graphify-out/graph.json, so installing
them globally is harmless in every other repo.
"""
import json
import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = ["graphify-nudge.sh", "graphify-mark.sh", "graphify-reset.sh", "graphify-banner.sh"]

# (event, matcher-or-None, script) -> what each hook registration looks like.
REGISTRATIONS = [
    ("PreToolUse", "Grep|Glob", "graphify-nudge.sh"),   # DENY raw browsing until the graph is queried this turn
    ("PostToolUse", "Bash", "graphify-mark.sh"),        # mark "graph consulted" when a graphify read ran
    ("UserPromptSubmit", None, "graphify-reset.sh"),    # new turn -> require a fresh consult
    ("SessionStart", None, "graphify-banner.sh"),       # announce the graph + the enforced rule
]


def entry_for(matcher, script):
    hook = {"type": "command", "command": f"bash ~/.claude/hooks/{script}", "shell": "bash", "timeout": 5}
    e = {"hooks": [hook]}
    if matcher:
        e["matcher"] = matcher
    return e


def main():
    config = os.environ.get("CLAUDE_CONFIG_DIR") or os.path.join(os.path.expanduser("~"), ".claude")
    hooks_dir = os.path.join(config, "hooks")
    os.makedirs(hooks_dir, exist_ok=True)
    os.makedirs(os.path.join(config, "state"), exist_ok=True)

    for s in SCRIPTS:
        src = os.path.join(HERE, s)
        dst = os.path.join(hooks_dir, s)
        shutil.copyfile(src, dst)
        try:
            os.chmod(dst, 0o755)
        except OSError:
            pass  # chmod is a no-op / may fail on Windows; the shell:"bash" runner does not need +x

    settings_path = os.path.join(config, "settings.json")
    try:
        with open(settings_path) as f:
            settings = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        settings = {}
    hooks = settings.setdefault("hooks", {})

    added = 0
    for event, matcher, script in REGISTRATIONS:
        arr = hooks.setdefault(event, [])
        if any(script in json.dumps(e) for e in arr):
            continue  # already registered
        arr.append(entry_for(matcher, script))
        added += 1

    with open(settings_path, "w") as f:
        json.dump(settings, f, indent=2)

    print(f"[graphify-hooks] installed {len(SCRIPTS)} scripts into {hooks_dir}")
    print(f"[graphify-hooks] {added} new registration(s) merged into {settings_path} "
          f"({len(REGISTRATIONS) - added} already present)")


if __name__ == "__main__":
    sys.exit(main())
