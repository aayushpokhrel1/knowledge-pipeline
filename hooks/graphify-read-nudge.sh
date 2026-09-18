#!/usr/bin/env bash
# PreToolUse (Read): gate EXPLORATION reads of code files the same way Grep/Glob are
# gated -- deny until `graphify query/path/explain` has run THIS TURN -- while staying
# usable so neither the user nor the model routes around it:
#   - non-code files (docs, config, migrations, fixtures, data) are ALWAYS allowed;
#   - the first $GRAPHIFY_READ_GRACE code files each turn are allowed, because
#     reading the file(s) you are about to Edit is legitimate and the graph does not
#     replace it (a PreToolUse hook cannot see a future Edit, so grace is the proxy);
#   - past that, reading another code file is DENIED until the graph is consulted.
# Same per-turn marker + visible `touch` bypass as graphify-nudge.sh. Silent, blocks
# nothing, in any repo without a graphify-out/graph.json.
input="$(cat)"
dir="${CLAUDE_PROJECT_DIR:-$PWD}"
[ -f "$dir/graphify-out/graph.json" ] || exit 0        # no graph -> never block
key="$(printf '%s' "$dir" | cksum | cut -d' ' -f1)"
marker="$HOME/.claude/state/graphify-ok.$key"
[ -f "$marker" ] && exit 0                             # graph consulted this turn -> allow

# Extract the Read target's extension from the tool-call JSON. The value is still
# JSON-escaped (Windows backslashes appear as \\), which the parameter expansions
# below strip cleanly; a path with no extension yields a non-code ext -> allowed.
path="$(printf '%s' "$input" | grep -oE '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed -E 's/.*:[[:space:]]*"(.*)"$/\1/')"
base="${path##*[/\\]}"
ext="${base##*.}"
ext="$(printf '%s' "$ext" | tr 'A-Z' 'a-z')"

# Only these extensions are gate-eligible; everything else (md json yaml toml sql txt
# csv lock env html css, no-extension files, ...) is exploration-neutral -> allowed.
# Tune this list to your stack.
case " py js jsx ts tsx mjs cjs go rs java rb php c h cc cpp cxx hpp cs swift kt scala sh bash lua " in
  *" $ext "*) : ;;              # code file -> subject to the gate
  *) exit 0 ;;                  # non-code -> allow
esac

# Read-before-edit grace: allow the first N code files this turn, gate the rest.
grace="${GRAPHIFY_READ_GRACE:-2}"          # ponytail: fixed grace; raise if legit multi-file edits get blocked often
count_file="$HOME/.claude/state/graphify-reads.$key"
n="$(cat "$count_file" 2>/dev/null || echo 0)"
case "$n" in ''|*[!0-9]*) n=0 ;; esac
if [ "$n" -lt "$grace" ]; then
  echo $((n + 1)) > "$count_file"          # count only reads we actually allow
  exit 0
fi

reason="[graphify] BLOCKED: reading a code file for exploration without consulting the knowledge graph this turn (already read $n code file(s), grace limit $grace). Run \`graphify query \\\"<question>\\\"\` (or \`graphify path \\\"A\\\" \\\"B\\\"\` / \`graphify explain \\\"X\\\"\`) FIRST -- it returns the file:line to read next. Non-code files (docs, config, migrations, fixtures) and the first $grace code reads (read-before-edit) are always allowed. If you genuinely must read this specific code file now (e.g. you are about to Edit it), bypass with: touch \\\"$marker\\\""
printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$reason"
exit 0
