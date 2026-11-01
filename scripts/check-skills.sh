#!/usr/bin/env bash
#
# Holds skills/ (and the hook docs) to the rules CLAUDE.md states, so they are
# not just prose.
#
#   bash scripts/check-skills.sh
#
# CLAUDE.md says "Nothing in skills/ may hardcode a path... A hardcoded
# C:\Users\<name>\... is a bug, not a detail." A document asking for that does
# not get it; this does. The skill is installed on more than one machine, and a
# path baked into it is wrong everywhere except the author's laptop.
set -u

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"
fails=0
report() { printf '  FAIL %s\n' "$1"; fails=$((fails + 1)); }

skills="$(find skills -name 'SKILL.md' 2>/dev/null)"
[ -n "$skills" ] || { echo "no skills/*/SKILL.md found"; exit 1; }

for f in $skills; do
  echo "checking $f"

  # 1. No machine-specific absolute paths. A documented placeholder is fine
  #    (<vault>, /mnt/<drive>/<tmp>), a real home directory is not.
  if grep -nE '(/home/[a-z]|/Users/[A-Za-z]|C:[/\\]+Users[/\\]+[A-Za-z]|/mnt/[a-z]/Users/[A-Za-z])' "$f" \
       | grep -vE '<[a-z]+>|Users/you|Users/someone' ; then
    report "$f hardcodes a home directory (see CLAUDE.md: nothing in skills/ may hardcode a path)"
  fi

  # 2. No assumed WSL distro. `wsl -l -q` is the only way to know it.
  if grep -nE 'wsl +-d +[A-Za-z]' "$f" | grep -vE 'wsl +-d +<' ; then
    report "$f assumes a WSL distro name; resolve it with 'wsl -l -q'"
  fi

  # 3. Frontmatter must be present, and name must match the directory, or the
  #    skill is listed under a name the slash command does not match.
  head -1 "$f" | grep -q '^---$' || report "$f does not start with YAML frontmatter"
  declared="$(sed -n '2,20p' "$f" | sed -n 's/^name: *//p' | head -1)"
  dirname_="$(basename "$(dirname "$f")")"
  [ -n "$declared" ] || report "$f has no 'name:' in its frontmatter"
  if [ -n "$declared" ] && [ "$declared" != "$dirname_" ]; then
    report "$f declares name '$declared' but lives in '$dirname_'; they must match"
  fi
  sed -n '2,20p' "$f" | grep -q '^description: ' \
    || report "$f has no 'description:' in its frontmatter"

  # 4. Every skill needs its command file, since CLAUDE.md promises both are
  #    installed together.
  [ -f "commands/$dirname_.md" ] || report "commands/$dirname_.md is missing for skill '$dirname_'"
done

# 5. Every graphify hook must be named in register-hooks.py and in BOTH doc
#    tables. Two hooks were added once and the README kept describing four of
#    them, with a design note that asserted the opposite of what the new one
#    did. A count in prose is the first thing to go stale when the set grows,
#    so check the names instead of the number.
for h in hooks/graphify-*.sh; do
  base="$(basename "$h")"
  grep -q "$base" hooks/register-hooks.py || report "$base is not in SCRIPTS in hooks/register-hooks.py"
  grep -q "$base" hooks/README.md         || report "$base is not documented in hooks/README.md"
  grep -q "$base" README.md               || report "$base is not in the hook table in README.md"
done

echo
if [ "$fails" -eq 0 ]; then
  echo "skills/ and hook-doc checks passed"
else
  echo "$fails problem(s) found"
  exit 1
fi
