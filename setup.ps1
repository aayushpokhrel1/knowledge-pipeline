<#
  Knowledge Pipeline setup (Windows / PowerShell)

  Installs the Graphify half natively (Graphify runs fine on native Windows),
  clones claude-obsidian, then hands the vault step to WSL, because vault writes
  require a POSIX filesystem. See the README section "Why the vault lives in WSL".
#>
$ErrorActionPreference = 'Stop'
$RepoDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$CoDir   = Join-Path $RepoDir 'claude-obsidian'
$CoUrl   = 'https://github.com/AgriciDaniel/claude-obsidian.git'

function Say($m)  { Write-Host "`n==> $m" -ForegroundColor Cyan }
function Warn($m) { Write-Host " warning: $m" -ForegroundColor Yellow }

# --- Python ----------------------------------------------------------------
$py = (Get-Command python -ErrorAction SilentlyContinue)
if (-not $py) { throw 'Python 3.10+ is required but was not found on PATH.' }
Say "Using Python: $(python --version)"

# --- uv --------------------------------------------------------------------
if (Get-Command uv -ErrorAction SilentlyContinue) {
  $uv = 'uv'
} else {
  try { python -m uv --version *> $null; $uv = 'python -m uv' }
  catch {
    Say 'Installing uv (Graphify''s package manager) via pip'
    python -m pip install --user -q uv
    $uv = 'python -m uv'
  }
}
Say "uv: $(Invoke-Expression "$uv --version")"

# --- Graphify --------------------------------------------------------------
Say 'Installing Graphify (graphifyy)'
try { Invoke-Expression "$uv tool install graphifyy" }
catch { Invoke-Expression "$uv tool upgrade graphifyy" }

Say 'Registering the /graphify Claude skill'
$graphify = Join-Path $env:USERPROFILE '.local\bin\graphify.exe'
if (Test-Path $graphify) { & $graphify install }
elseif (Get-Command graphify -ErrorAction SilentlyContinue) { graphify install }
else { Warn 'graphify not on PATH yet. Open a new terminal and run: graphify install' }

# --- claude-obsidian -------------------------------------------------------
if (Test-Path (Join-Path $CoDir '.git')) {
  Say "claude-obsidian already present at $CoDir (skipping clone)"
} else {
  Say "Cloning claude-obsidian into $CoDir"
  git clone --depth 1 $CoUrl $CoDir
}

# --- Vault (delegated to WSL) ---------------------------------------------
$wsl = Get-Command wsl -ErrorAction SilentlyContinue
if ($wsl) {
  Say 'Building the vault inside WSL (writes need a POSIX filesystem)'
  # Run setup.sh from within WSL against the WSL home filesystem.
  $repoWsl = (wsl wslpath -a "$RepoDir").Trim()
  # Graphify is already installed natively above, so skip it inside WSL and just
  # build the vault on the POSIX filesystem.
  wsl bash -lc "cd '$repoWsl' && KP_SKIP_GRAPHIFY=1 VAULT_DIR=`$HOME/knowledge-vault CO_DIR='$repoWsl/claude-obsidian' bash ./setup.sh"
} else {
  Warn 'WSL not found. Install it with:  wsl --install'
  Warn 'Then re-run this script, or run ./setup.sh inside WSL to build the vault.'
}

Say 'Setup complete.'
@"

Next steps
----------
1. Install Obsidian (free): https://obsidian.md
2. Open the vault in Obsidian -> "Open folder as vault":
     \\wsl.localhost\<Distro>\home\<you>\knowledge-vault
3. Let Claude maintain the vault (run inside WSL):
     cd ~/knowledge-vault
     claude --plugin-dir /mnt/.../knowledge-pipeline/claude-obsidian
   Then: /claude-obsidian:wiki
4. Map any codebase (native Windows is fine):
     graphify .        # or /graphify . inside Claude Code
"@ | Write-Host
