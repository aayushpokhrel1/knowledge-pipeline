#!/usr/bin/env bash
# PreToolUse (Grep|Glob): if this project has a graphify graph, DENY raw browsing
# until `graphify query/path/explain` has run THIS TURN (a per-turn marker set by
# graphify-mark.sh and cleared by graphify-reset.sh). Silent/allow where there is
# no graph. Bypass for a genuine exact-string/filename search: touch the marker
# (visible in the transcript), e.g. `touch "$marker"` printed in the deny reason.
cat >/dev/null 2>&1   # drain stdin
dir="${CLAUDE_PROJECT_DIR:-$PWD}"
[ -f "$dir/graphify-out/graph.json" ] || exit 0   # no graph -> never block
key="$(printf '%s' "$dir" | cksum | cut -d' ' -f1)"
marker="$HOME/.claude/state/graphify-ok.$key"
if [ -f "$marker" ]; then exit 0; fi              # already consulted this turn -> allow
reason="[graphify] BLOCKED: this repo has a knowledge graph but you have not queried it this turn. Run \`graphify query \\\"<question>\\\"\` (or \`graphify path \\\"A\\\" \\\"B\\\"\` / \`graphify explain \\\"X\\\"\`) FIRST, then this Grep/Glob is allowed for the rest of the turn. If this is a genuine exact-string or filename search (the graph is worse than grep for those), bypass with: touch \\\"$marker\\\""
printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$reason"
exit 0
