#!/usr/bin/env bash
#
# Smoke test for scripts/install-scaffold.sh. Runs the real installer against a
# throwaway directory, never your actual ~/.claude.
#
#   bash scripts/test-install-scaffold.sh
#
# The point: the whole value of the setup scripts is working on a machine that
# is not the author's, and nothing proved they did. A syntax check cannot tell
# you the config came out as valid JSON or that a second run is idempotent.
set -u

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Same reason as kp_scaffold_py: a python on PATH is not necessarily a python that
# runs (the Windows Store stub). Verify by executing it.
PY=""
for c in python3 python py; do
  command -v "$c" >/dev/null 2>&1 || continue
  if "$c" -c 'pass' >/dev/null 2>&1; then PY="$c"; break; fi
done
[ -n "$PY" ] || { echo "no working python found; cannot run these checks"; exit 1; }
fails=0
pass() { printf '  ok   %s\n' "$1"; }
fail() { printf '  FAIL %s\n' "$1"; fails=$((fails + 1)); }
check() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (expected [$3], got [$2])"; fi; }

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

# Quiet the installer's own chatter; we assert on the filesystem, not the log.
say()  { :; }
warn() { :; }
# shellcheck source=scripts/install-scaffold.sh
. "$REPO_DIR/scripts/install-scaffold.sh"

json_get() { CFG="$1" KEY="$2" "$PY" -c 'import json, os
with open(os.environ["CFG"], encoding="utf-8") as f:
    print(json.load(f).get(os.environ["KEY"]))'; }

# --- 1. a clean install ----------------------------------------------------
# The vault fixture is a real path under the sandbox, not an invented
# "/home/someone/..." one: Git Bash rewrites a bare POSIX path on its way into a
# native python ("C:/Program Files/Git/home/..."), so an invented path would make
# this assertion fail on Windows for a reason that has nothing to do with the
# installer. A path that already exists in the platform's own form cannot be
# rewritten. Case 3 covers the Windows-shaped path explicitly.
echo "1. clean install into an empty directory"
C1="$SANDBOX/clean"
VAULT_FIXTURE="$SANDBOX/fake-vault"
mkdir -p "$VAULT_FIXTURE"
KP_CLAUDE_DIR="$C1" KP_VAULT="$VAULT_FIXTURE" install_project_scaffold >/dev/null

[ -e "$C1/skills/project-scaffold/SKILL.md" ] && pass "skill installed" || fail "skill missing"
[ -e "$C1/commands/project-scaffold.md" ]     && pass "command installed" || fail "command missing"
[ -e "$C1/project-scaffold.config.json" ]     && pass "config written" || fail "config missing"
[ -e "$C1/bin/vault-note.py" ]                && pass "vault-note installed" || fail "vault-note missing"
# Reading SKILL.md through the install path proves the link actually resolves.
grep -q '^name: project-scaffold' "$C1/skills/project-scaffold/SKILL.md" \
  && pass "skill readable through the install path" || fail "skill unreadable through the install path"
# Asserted by suffix, not exact string: on Git Bash the same directory has two
# spellings ("/tmp/x/fake-vault" to bash, "C:/Users/.../Temp/x/fake-vault" to a
# native python), so an equality check would fail on Windows over spelling alone.
# Case 3 is the exact round-trip proof; this one only has to show a real vault
# was recorded rather than null or empty.
got_vault="$(json_get "$C1/project-scaffold.config.json" vault)"
case "$got_vault" in
  */fake-vault) pass "config is valid json and records the vault" ;;
  *) fail "config vault looks wrong (got [$got_vault])" ;;
esac

# --- 2. no vault -> null, not the empty string -----------------------------
echo "2. no vault resolved"
C2="$SANDBOX/novault"
KP_CLAUDE_DIR="$C2" VAULT_SKIP=1 KP_VAULT="/ignored" install_project_scaffold >/dev/null
check "vault is null when VAULT_SKIP=1" \
  "$(json_get "$C2/project-scaffold.config.json" vault)" "None"

# --- 3. a path with a backslash stays valid json ---------------------------
# This is the bug that shipped once: "C:\Users" hand-written into JSON is
# invalid, because \U is not a legal escape, and the skill silently re-probes.
echo "3. a Windows-style path round-trips"
C3="$SANDBOX/winpath"
KP_CLAUDE_DIR="$C3" KP_VAULT='C:\Users\someone\Documents\Knowledge-Vault' install_project_scaffold >/dev/null
check "backslash path round-trips through json" \
  "$(json_get "$C3/project-scaffold.config.json" vault)" 'C:\Users\someone\Documents\Knowledge-Vault'

# --- 4. idempotent, and a hand-edited config is never clobbered ------------
echo "4. second run is idempotent and preserves the config"
printf '{\n  "vault": "/edited/by/hand",\n  "wsl": true\n}\n' > "$C1/project-scaffold.config.json"
KP_CLAUDE_DIR="$C1" KP_VAULT="$VAULT_FIXTURE" install_project_scaffold >/dev/null
check "hand-edited vault survives a re-run" \
  "$(json_get "$C1/project-scaffold.config.json" vault)" "/edited/by/hand"
[ -e "$C1/skills/project-scaffold/SKILL.md" ] && pass "skill still installed after re-run" \
  || fail "re-run broke the install"

# --- 5. a real directory is backed up OUTSIDE skills/ ----------------------
# A backup left inside skills/ is itself read as a skill, so Claude lists a
# second, stale copy of this skill under the backup's name.
echo "5. an existing real directory is moved aside, not into skills/"
C5="$SANDBOX/occupied"
mkdir -p "$C5/skills/project-scaffold" "$C5/commands"
echo "someone else's skill" > "$C5/skills/project-scaffold/SKILL.md"
KP_CLAUDE_DIR="$C5" KP_VAULT="/v" install_project_scaffold >/dev/null
strays="$(find "$C5/skills" -maxdepth 1 -name '*.bak-*' | wc -l | tr -d ' ')"
check "no backup left inside skills/" "$strays" "0"
kept="$(find "$C5/.backups" -maxdepth 1 -name 'project-scaffold.bak-*' 2>/dev/null | wc -l | tr -d ' ')"
check "the displaced directory is kept in .backups" "$kept" "1"
grep -q '^name: project-scaffold' "$C5/skills/project-scaffold/SKILL.md" \
  && pass "ours is installed in its place" || fail "ours did not replace it"

echo
if [ "$fails" -eq 0 ]; then
  echo "all checks passed"
else
  echo "$fails check(s) failed"
  exit 1
fi
