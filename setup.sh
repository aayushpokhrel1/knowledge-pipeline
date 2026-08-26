#!/usr/bin/env bash
#
# Knowledge Pipeline setup (Linux / macOS / WSL)
# Installs Graphify, clones claude-obsidian, and builds an Obsidian vault.
#
# Overridable env vars:
#   VAULT_DIR          where to create the vault (default: $HOME/knowledge-vault)
#   CO_DIR             where to clone claude-obsidian (default: ./claude-obsidian)
#   KP_SKIP_GRAPHIFY=1 skip the Graphify install (e.g. already installed on the host OS)
#   KP_NO_REMOTE_UV=1  never fetch uv from the network; only use pip/pipx/existing tools
#
set -uo pipefail   # note: no -e; Graphify install is best-effort, the vault step must still run

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT_DIR="${VAULT_DIR:-$HOME/knowledge-vault}"
CO_DIR="${CO_DIR:-$REPO_DIR/claude-obsidian}"
CO_URL="https://github.com/AgriciDaniel/claude-obsidian.git"
export PATH="$HOME/.local/bin:$PATH"

say()  { printf '\n\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m warning:\033[0m %s\n' "$*"; }

# --- Detect platform -------------------------------------------------------
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    echo "This looks like native Windows (Git Bash). Run setup.ps1 in PowerShell,"
    echo "or run this script from inside WSL. Vault writes require WSL on Windows."
    exit 1 ;;
esac
IS_WSL=0
grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null && IS_WSL=1

# --- Python ----------------------------------------------------------------
PY="$(command -v python3 || command -v python || true)"
[ -n "$PY" ] || { echo "Python 3.10+ is required but was not found."; exit 1; }
say "Using Python: $("$PY" --version 2>&1)"

# --- Graphify (best-effort) ------------------------------------------------
install_graphify() {
  # Resolve a uv invocation, bootstrapping one if we can.
  local UV=""
  if command -v uv >/dev/null 2>&1; then UV="uv"
  elif "$PY" -m uv --version >/dev/null 2>&1; then UV="$PY -m uv"
  elif command -v pipx >/dev/null 2>&1; then
    say "Installing Graphify via pipx"
    pipx install graphifyy || pipx upgrade graphifyy || true
    UV="skip"
  elif "$PY" -m pip --version >/dev/null 2>&1; then
    say "Installing uv via pip"
    "$PY" -m pip install --user -q uv && UV="$PY -m uv"
  elif "$PY" -m ensurepip --version >/dev/null 2>&1; then
    say "Bootstrapping pip via ensurepip, then installing uv"
    "$PY" -m ensurepip --user >/dev/null 2>&1 && "$PY" -m pip install --user -q uv && UV="$PY -m uv"
  fi

  if [ -z "$UV" ] && [ "${KP_NO_REMOTE_UV:-0}" != 1 ]; then
    if command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1; then
      say "No pip/pipx found; installing uv via the official installer (https://astral.sh/uv)"
      if command -v curl >/dev/null 2>&1; then curl -LsSf https://astral.sh/uv/install.sh | sh
      else wget -qO- https://astral.sh/uv/install.sh | sh; fi
      export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
      command -v uv >/dev/null 2>&1 && UV="uv"
    fi
  fi

  if [ -z "$UV" ]; then
    warn "Could not install Graphify automatically (no uv/pipx/pip on this system)."
    warn "Install it later with either:  pipx install graphifyy   or   uv tool install graphifyy"
    return 0
  fi

  if [ "$UV" != "skip" ]; then
    say "Installing Graphify (graphifyy)"
    $UV tool install graphifyy || $UV tool upgrade graphifyy || true
  fi

  local GRAPHIFY
  GRAPHIFY="$(command -v graphify || echo "$HOME/.local/bin/graphify")"
  if command -v graphify >/dev/null 2>&1 || [ -x "$GRAPHIFY" ]; then
    say "Registering the /graphify Claude skill"
    "$GRAPHIFY" install 2>/dev/null || graphify install || warn "run 'graphify install' manually later"
  else
    warn "graphify not on PATH yet. Open a new shell, then run: graphify install"
  fi
}

if [ "${KP_SKIP_GRAPHIFY:-0}" = 1 ]; then
  say "Skipping Graphify install (KP_SKIP_GRAPHIFY=1)"
else
  install_graphify
fi

# --- claude-obsidian -------------------------------------------------------
if [ -d "$CO_DIR/.git" ]; then
  say "claude-obsidian already present at $CO_DIR (skipping clone)"
else
  say "Cloning claude-obsidian into $CO_DIR"
  git clone --depth 1 "$CO_URL" "$CO_DIR" || { warn "clone failed"; exit 1; }
fi

# --- Vault (the part that truly needs a POSIX filesystem) ------------------
case "$VAULT_DIR" in
  /mnt/*) if [ "$IS_WSL" = 1 ]; then
            warn "VAULT_DIR is on a Windows mount (/mnt/...). Writes there fail with RESULT_DRIFT."
            warn "Use a path inside WSL, e.g. \$HOME/knowledge-vault. Skipping vault creation."
            VAULT_SKIP=1
          fi ;;
esac

if [ "${VAULT_SKIP:-0}" != 1 ]; then
  say "Building vault at $VAULT_DIR"
  mkdir -p "$VAULT_DIR"
  cd "$CO_DIR"
  if "$PY" scripts/claude-obsidian.py doctor --vault "$VAULT_DIR" >/dev/null 2>&1; then
    say "Vault already initialized and healthy (skipping)"
  else
    # Pre-created dir -> existing-dir path; one pinned timestamp so the dry-run
    # approval hash matches the apply.
    GA="$(date -u +%Y-%m-%dT%H:%M:%SZ)"; OP="kp-init"
    HASH="$("$PY" scripts/claude-obsidian.py init "$VAULT_DIR" \
              --generated-at "$GA" --operation-id "$OP" 2>/dev/null \
            | "$PY" -c 'import sys,json; print(json.load(sys.stdin)["approved_plan_sha256"])')"
    if [ -n "$HASH" ]; then
      say "Reviewed plan hash: $HASH"
      "$PY" scripts/claude-obsidian.py init "$VAULT_DIR" \
        --generated-at "$GA" --operation-id "$OP" \
        --approved-plan-sha256 "$HASH" --apply >/dev/null \
        && "$PY" scripts/claude-obsidian.py doctor --vault "$VAULT_DIR" | grep -E '"ok"' \
        || warn "vault init did not complete; run it manually (see README)"
    else
      warn "could not produce an init plan; is this a write-capable platform (WSL/Linux/macOS)?"
    fi
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
