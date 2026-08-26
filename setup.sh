#!/usr/bin/env bash
#
# Knowledge Pipeline setup (Linux / macOS / WSL)
# Installs Graphify, clones claude-obsidian, and builds an Obsidian vault.
#
# Overridable env vars:
#   VAULT_DIR   where to create the vault (default: $HOME/knowledge-vault)
#   CO_DIR      where to clone claude-obsidian (default: ./claude-obsidian)
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT_DIR="${VAULT_DIR:-$HOME/knowledge-vault}"
CO_DIR="${CO_DIR:-$REPO_DIR/claude-obsidian}"
CO_URL="https://github.com/AgriciDaniel/claude-obsidian.git"

say()  { printf '\n\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m warning:\033[0m %s\n' "$*"; }

# --- Detect platform -------------------------------------------------------
UNAME="$(uname -s)"
IS_WSL=0
if grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then IS_WSL=1; fi
case "$UNAME" in
  MINGW*|MSYS*|CYGWIN*)
    echo "This looks like native Windows (Git Bash). Run setup.ps1 in PowerShell,"
    echo "or run this script from inside WSL. Vault writes require WSL on Windows."
    exit 1 ;;
esac

# --- Python ----------------------------------------------------------------
PY="$(command -v python3 || command -v python || true)"
[ -n "$PY" ] || { echo "Python 3.10+ is required but was not found."; exit 1; }
say "Using Python: $("$PY" --version 2>&1)"

# --- uv --------------------------------------------------------------------
if command -v uv >/dev/null 2>&1; then
  UV="uv"
elif "$PY" -m uv --version >/dev/null 2>&1; then
  UV="$PY -m uv"
else
  say "Installing uv (Graphify's package manager) via pip"
  "$PY" -m pip install --user -q uv
  UV="$PY -m uv"
fi
say "uv: $($UV --version 2>&1 | head -1)"

# --- Graphify --------------------------------------------------------------
say "Installing Graphify (graphifyy)"
$UV tool install graphifyy || $UV tool upgrade graphifyy || true

GRAPHIFY="$(command -v graphify || echo "$HOME/.local/bin/graphify")"
if [ -x "$GRAPHIFY" ] || command -v graphify >/dev/null 2>&1; then
  say "Registering the /graphify Claude skill"
  "$GRAPHIFY" install || graphify install || warn "graphify install failed; run it manually later"
else
  warn "graphify binary not on PATH yet. Restart your shell, then run: graphify install"
fi

# --- claude-obsidian -------------------------------------------------------
if [ -d "$CO_DIR/.git" ]; then
  say "claude-obsidian already present at $CO_DIR (skipping clone)"
else
  say "Cloning claude-obsidian into $CO_DIR"
  git clone --depth 1 "$CO_URL" "$CO_DIR"
fi

# --- Vault -----------------------------------------------------------------
if [ "$IS_WSL" = 1 ] && case "$VAULT_DIR" in /mnt/*) true;; *) false;; esac; then
  warn "VAULT_DIR is on a Windows mount (/mnt/...). This will fail with RESULT_DRIFT."
  warn "Use a path inside WSL, e.g. \$HOME/knowledge-vault. Skipping vault creation."
else
  say "Building vault at $VAULT_DIR"
  # Pre-create the dir so init takes the existing-dir path (avoids the
  # absent->present transition edge case), then dry-run + apply with a single
  # pinned timestamp so the approval hash matches.
  mkdir -p "$VAULT_DIR"
  GA="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  OP="kp-init"
  cd "$CO_DIR"
  if "$PY" scripts/claude-obsidian.py doctor --vault "$VAULT_DIR" >/dev/null 2>&1; then
    say "Vault already initialized and healthy (skipping)"
  else
    HASH="$("$PY" scripts/claude-obsidian.py init "$VAULT_DIR" \
              --generated-at "$GA" --operation-id "$OP" 2>/dev/null \
            | "$PY" -c 'import sys,json; print(json.load(sys.stdin)["approved_plan_sha256"])')"
    say "Reviewed plan hash: $HASH"
    "$PY" scripts/claude-obsidian.py init "$VAULT_DIR" \
      --generated-at "$GA" --operation-id "$OP" \
      --approved-plan-sha256 "$HASH" --apply >/dev/null
    "$PY" scripts/claude-obsidian.py doctor --vault "$VAULT_DIR" | grep -E '"ok"' || true
  fi
  cd "$REPO_DIR"
fi

# --- Done ------------------------------------------------------------------
say "Setup complete."
cat <<EOF

Next steps
----------
1. Install Obsidian (free): https://obsidian.md
2. Open the vault in Obsidian -> "Open folder as vault":
     $VAULT_DIR
   (On Windows/WSL, that's \\\\wsl.localhost\\<Distro>$VAULT_DIR )
3. Let Claude maintain the vault (from this write-capable shell):
     cd "$VAULT_DIR"
     claude --plugin-dir "$CO_DIR"
   Then: /claude-obsidian:wiki
4. Map any codebase:
     graphify .        # or /graphify . inside Claude Code
EOF
