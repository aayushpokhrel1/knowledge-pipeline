#!/usr/bin/env bash
#
# Installs skills/project-scaffold and its /project-scaffold command into
# ~/.claude as a USER-LEVEL skill, not a plugin: a plugin copy would show up
# alongside the user-level one under a second name and the two would collide.
#
# Linked at the repo so `git pull` updates the installed skill in place, with a
# copy as the fallback for a filesystem that refuses symlinks (Windows without
# Developer Mode).
#
# This file is SOURCED, by setup.sh and by scripts/test-install-scaffold.sh. It
# must define functions and nothing else: no side effects at source time, so a
# test can source it, point HOME at a sandbox and call one function. The same
# split hooks/register-hooks.py already uses.
#
# Inputs, all overridable so the test can sandbox them:
#   KP_REPO_DIR    the checkout to link at        (default: this file's parent's parent)
#   KP_CLAUDE_DIR  where to install               (default: $HOME/.claude)
#   KP_VAULT       vault path for the config      (default: empty -> "vault": null)
#   KP_PY          python to dump json with        (default: python3, then python)

# say/warn may already exist (setup.sh defines them); define only if missing so
# sourcing never clobbers the caller's nicer coloured versions.
command -v say  >/dev/null 2>&1 || say()  { printf '\n==> %s\n' "$*"; }
command -v warn >/dev/null 2>&1 || warn() { printf ' warning: %s\n' "$*"; }

# Pick a python that actually RUNS, not merely one that is on PATH. On Windows,
# `python3` is often the Microsoft Store stub: `command -v` finds it, and running
# it prints "Python was not found" and exits non-zero. Confirmed on 2026-10-26,
# where it silently cost the config file. So execute each candidate once.
kp_scaffold_py() {
  for c in ${KP_PY:+"$KP_PY"} python3 python py; do
    command -v "$c" >/dev/null 2>&1 || continue
    "$c" -c 'pass' >/dev/null 2>&1 && { printf '%s' "$c"; return 0; }
  done
  return 1
}

# Replace $2 with a link to $1. An existing symlink is ours to replace; a real
# file or directory is the user's, so it is moved aside rather than deleted.
link_or_copy() {
  src="$1"; dst="$2"
  [ -e "$src" ] || { warn "missing $src; skipping"; return 1; }
  if [ -L "$dst" ]; then
    rm -f "$dst"
  elif [ -e "$dst" ]; then
    # Back up OUTSIDE <claude>/skills. A "project-scaffold.bak-<stamp>/" left in there
    # is itself read as a skill, so Claude lists a second, stale copy of this skill under
    # the backup's name. Confirmed on 2026-10-26.
    bakdir="${KP_CLAUDE_DIR:-$HOME/.claude}/.backups"
    mkdir -p "$bakdir"
    bak="$bakdir/$(basename "$dst").bak-$(date -u +%Y%m%d%H%M%S)"
    warn "$dst already exists and is not a link; moving it to $bak"
    mv "$dst" "$bak" || { warn "could not move it aside; skipping"; return 1; }
  fi
  if ln -s "$src" "$dst" 2>/dev/null; then
    printf '    linked %s\n' "$dst"
  elif cp -R "$src" "$dst"; then
    printf '    copied %s (symlinks unavailable: re-run this script after a git pull)\n' "$dst"
  else
    warn "could not install $dst"
    return 1
  fi
}

install_project_scaffold() {
  repo="${KP_REPO_DIR:-${REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}}"
  claude_dir="${KP_CLAUDE_DIR:-$HOME/.claude}"

  say "Installing the project-scaffold skill into $claude_dir"
  mkdir -p "$claude_dir/skills" "$claude_dir/commands"
  link_or_copy "$repo/skills/project-scaffold" "$claude_dir/skills/project-scaffold" || return 1
  link_or_copy "$repo/commands/project-scaffold.md" "$claude_dir/commands/project-scaffold.md" || return 1

  # Seed the per-machine config so the skill never probes for the vault or
  # hardcodes a path. Written only when absent, so a hand-edited path survives.
  cfg="$claude_dir/project-scaffold.config.json"
  if [ -e "$cfg" ]; then
    say "Keeping the existing $cfg"
    return 0
  fi

  py="$(kp_scaffold_py)" || { warn "no python found; skipping $cfg"; return 1; }

  # Dumped by python, not printf: a path containing a backslash produces invalid
  # JSON by hand ("C:\Users" fails, because \U is not a legal escape), and the
  # skill then silently falls back to probing. Hit on 2026-10-26.
  #
  # Paths go through the environment, never the command line, so a path with a
  # space or a backslash cannot be re-split or re-escaped on the way in.
  if [ "${VAULT_SKIP:-0}" = 1 ]; then cfg_vault=""; else cfg_vault="${KP_VAULT:-${VAULT_DIR:-}}"; fi
  CFG_PATH="$cfg" CFG_VAULT="$cfg_vault" "$py" -c 'import json, os
vault = os.environ.get("CFG_VAULT") or None
with open(os.environ["CFG_PATH"], "w", encoding="utf-8", newline="\n") as f:
    json.dump({"vault": vault, "wsl": False}, f, indent=2)
    f.write("\n")' || { warn "could not write $cfg"; return 1; }
  say "Wrote $cfg"
}
