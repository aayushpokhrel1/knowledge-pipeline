#!/usr/bin/env bash
# Stop: backstop for the query-first rule. If this turn browsed code (grace reads
# happened via graphify-read-nudge.sh) but the graph was never consulted, record the
# miss so scoped-out or bypassed browsing is still surfaced -- even where a hard block
# was deliberately not applied. NON-BLOCKING: it logs, it never prevents the turn from
# ending. Reads $HOME/.claude/state/graphify-misses.log; tail it to review misses.
cat >/dev/null 2>&1
dir="${CLAUDE_PROJECT_DIR:-$PWD}"
[ -f "$dir/graphify-out/graph.json" ] || exit 0
key="$(printf '%s' "$dir" | cksum | cut -d' ' -f1)"
marker="$HOME/.claude/state/graphify-ok.$key"
[ -f "$marker" ] && exit 0                        # graph was consulted (or bypassed via touch) -> no miss
count_file="$HOME/.claude/state/graphify-reads.$key"
n="$(cat "$count_file" 2>/dev/null || echo 0)"
case "$n" in ''|*[!0-9]*) n=0 ;; esac
[ "$n" -gt 0 ] || exit 0                           # no code browsed this turn -> nothing to flag
printf '%s\t%s\t%s code read(s), no graphify query\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$dir" "$n" \
  >> "$HOME/.claude/state/graphify-misses.log"
exit 0
