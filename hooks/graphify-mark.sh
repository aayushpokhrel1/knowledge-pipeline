#!/usr/bin/env bash
# PostToolUse (Bash): if the command that just ran consulted the graph, record it
# for this turn so Grep/Glob are unblocked. Reads the tool call JSON from stdin.
input="$(cat)"
dir="${CLAUDE_PROJECT_DIR:-$PWD}"
[ -f "$dir/graphify-out/graph.json" ] || exit 0
# Match a real graph read: `graphify query|path|explain|god-nodes|affected|read`.
if printf '%s' "$input" | grep -Eq 'graphify[[:space:]]+(query|path|explain|god-nodes|affected|read)\b'; then
  key="$(printf '%s' "$dir" | cksum | cut -d' ' -f1)"
  : > "$HOME/.claude/state/graphify-ok.$key"
fi
exit 0
