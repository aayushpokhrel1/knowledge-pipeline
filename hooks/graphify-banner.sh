#!/usr/bin/env bash
# SessionStart: announce the graphify graph and the query-first rule when the
# current project has one. Silent in projects with no graph.
cat >/dev/null 2>&1   # consume stdin
dir="${CLAUDE_PROJECT_DIR:-$PWD}"
if [ -f "$dir/graphify-out/graph.json" ]; then
  cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"[graphify] This project has a knowledge graph (graphify-out/graph.json). Per CLAUDE.md, for codebase questions (where/how/what-calls/trace) run `graphify query \"...\"`, `graphify path`, or `graphify explain` BEFORE Grep/Read; read graphify-out/GRAPH_REPORT.md only for broad architecture review. ENFORCED: a PreToolUse hook now DENIES Grep/Glob each turn until you have run a graphify query/path/explain that turn (Read stays a nudge). Bypass for a true exact-string/filename search is a visible `touch` of the per-turn marker named in the deny message."}}
JSON
fi
exit 0
