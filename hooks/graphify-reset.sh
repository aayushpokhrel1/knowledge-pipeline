#!/usr/bin/env bash
# UserPromptSubmit: a new turn begins -> require a fresh graph consult before the
# next Grep/Glob/Read. Clears this project's per-turn marker and code-read counter.
# The persistent misses log is left intact. Silent where no graph.
cat >/dev/null 2>&1
dir="${CLAUDE_PROJECT_DIR:-$PWD}"
[ -f "$dir/graphify-out/graph.json" ] || exit 0
key="$(printf '%s' "$dir" | cksum | cut -d' ' -f1)"
rm -f "$HOME/.claude/state/graphify-ok.$key" "$HOME/.claude/state/graphify-reads.$key"
exit 0
