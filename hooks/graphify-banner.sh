#!/usr/bin/env bash
# SessionStart: announce the graphify graph and the query-first rule when the
# current project has one. Silent in projects with no graph.
cat >/dev/null 2>&1   # consume stdin
dir="${CLAUDE_PROJECT_DIR:-$PWD}"
if [ -f "$dir/graphify-out/graph.json" ]; then
  cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"[graphify] This project has a knowledge graph (graphify-out/graph.json). Per CLAUDE.md, for codebase questions (where/how/what-calls/trace) run `graphify query \"...\"`, `graphify path`, or `graphify explain` BEFORE Grep/Read; read graphify-out/GRAPH_REPORT.md only for broad architecture review. ENFORCED: PreToolUse hooks DENY Grep/Glob, and DENY reading code files for exploration, each turn until you have run a graphify query/path/explain that turn. Reading non-code files (docs/config/migrations/fixtures) and the first couple of code files each turn (read-before-edit) stay allowed. Bypass for a true exact-string/filename search, or to read a specific code file you are about to Edit, is a visible `touch` of the per-turn marker named in the deny message."}}
JSON
fi
exit 0
