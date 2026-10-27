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

# Query-first ENFORCEMENT hooks -> ~/.claude. They DENY Grep/Glob in any repo with a
# graphify graph until `graphify query/path/explain` has run that turn, so the graph is
# used, not routed around. Installed natively here (native Windows Claude Code reads
# %USERPROFILE%\.claude), so the WSL handoff below passes KP_SKIP_GRAPHIFY=1 and does
# not re-install them into WSL's ~/.claude. Idempotent. See hooks/README.
Say 'Installing the graphify query-first hooks (Claude Code)'
try { python (Join-Path $RepoDir 'hooks\register-hooks.py') }
catch { Warn 'hook install failed; run it later with: python hooks\register-hooks.py' }

# --- Optional skills (opt-in) ---------------------------------------------
# Set $env:KP_WITH_SKILLS = '1' to also install the two writing/code-hygiene skills:
#   humanizer  strips AI-tells from prose (model-invoked or /humanizer)
#   ponytail   keeps generated code minimal (auto-active each session)
# Opt-in: they pull from external repos and need node/npx and the Claude CLI.
if ($env:KP_WITH_SKILLS -eq '1') {
  if (Get-Command npx -ErrorAction SilentlyContinue) {
    Say 'Installing the humanizer skill (npx skills add blader/humanizer)'
    try { npx -y skills add blader/humanizer --global } catch { Warn 'humanizer install failed; run it manually later' }
  } else {
    Warn 'node/npx not found; skipping humanizer. Install Node.js, then: npx skills add blader/humanizer --global'
  }

  if (Get-Command claude -ErrorAction SilentlyContinue) {
    Say 'Installing the ponytail plugin (Claude Code marketplace)'
    try { claude plugin marketplace add DietrichGebert/ponytail } catch { }
    try { claude plugin install ponytail@ponytail } catch { Warn 'ponytail install failed; run it manually later' }
  } else {
    Warn 'claude CLI not found; skipping ponytail. Install Claude Code, then: claude plugin install ponytail@ponytail'
  }
}

# --- claude-obsidian -------------------------------------------------------
if (Test-Path (Join-Path $CoDir '.git')) {
  Say "claude-obsidian already present at $CoDir (skipping clone)"
} else {
  Say "Cloning claude-obsidian into $CoDir"
  git clone --depth 1 $CoUrl $CoDir
}

# --- Vault (built in WSL, stored on the Windows drive) --------------------
# The vault lives on the Windows drive so Obsidian can open it as a local folder,
# but it is written to from WSL, which requires POSIX metadata on the mount.
$wsl = Get-Command wsl -ErrorAction SilentlyContinue
if ($wsl) {
  $repoWsl = (wsl wslpath -a "$RepoDir").Trim()
  $meta = (wsl bash -lc "grep -qE '/mnt/[a-z]+ .*metadata' /proc/mounts && echo yes || echo no").Trim()
  if ($meta -eq 'yes') {
    $winVault = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Knowledge-Vault'
    $vaultWsl = (wsl wslpath -a "$winVault").Trim()
    Say "Metadata enabled; building the vault on your Windows drive at $winVault"
    # Graphify is already installed natively above, so skip it inside WSL. Same for
    # project-scaffold: native Windows Claude Code reads %USERPROFILE%\.claude, so it
    # is installed natively below rather than into WSL's ~/.claude.
    wsl bash -lc "cd '$repoWsl' && KP_SKIP_GRAPHIFY=1 KP_SKIP_SCAFFOLD=1 VAULT_DIR='$vaultWsl' CO_DIR='$repoWsl/claude-obsidian' bash ./setup.sh"
    Say "Open this folder in Obsidian: $winVault"
    $script:WinVaultPath = $winVault
  } else {
    Warn 'WSL is missing POSIX metadata on the Windows mount, needed so Obsidian and the'
    Warn 'plugin can share one vault on your Windows drive. Enable it once:'
    Warn '  1) PowerShell:  wsl -u root'
    Warn '  2) WSL:         printf ''[automount]\noptions = "metadata"\n'' > /etc/wsl.conf ; exit'
    Warn '  3) PowerShell:  wsl --shutdown'
    Warn 'Then re-run ./setup.ps1 to build the vault. (See README > Windows setup.)'
  }
} else {
  Warn 'WSL not found. Install it with:  wsl --install'
  Warn 'Then do the one-time metadata step (README > Windows setup) and re-run this script.'
}

# --- project-scaffold (this repo's own skill) ------------------------------
# Installed natively, because native Windows Claude Code reads %USERPROFILE%\.claude.
# A USER-LEVEL skill, not a plugin: a plugin copy would appear under a second name
# beside the user-level one and the two would collide.
#
# A directory junction and a file hard link both work WITHOUT administrator rights or
# Developer Mode, unlike a symbolic link, and both keep the installed copy pointing at
# the repo so `git pull` updates it in place. Copy-Item is the last resort.
function Install-ProjectScaffold {
  Say 'Installing the project-scaffold skill into ~/.claude'
  $claudeDir = Join-Path $env:USERPROFILE '.claude'
  New-Item -ItemType Directory -Force -Path (Join-Path $claudeDir 'skills') | Out-Null
  New-Item -ItemType Directory -Force -Path (Join-Path $claudeDir 'commands') | Out-Null

  $pairs = @(
    @{ Src = (Join-Path $RepoDir 'skills\project-scaffold'); Dst = (Join-Path $claudeDir 'skills\project-scaffold'); Kind = 'Junction' },
    @{ Src = (Join-Path $RepoDir 'commands\project-scaffold.md'); Dst = (Join-Path $claudeDir 'commands\project-scaffold.md'); Kind = 'HardLink' }
  )

  foreach ($p in $pairs) {
    if (-not (Test-Path $p.Src)) { Warn "missing $($p.Src); skipping"; continue }
    $existing = Get-Item $p.Dst -Force -ErrorAction SilentlyContinue
    if ($existing) {
      # A junction/link is ours to replace; anything real is the user's, so move it aside.
      if ($existing.LinkType) {
        Remove-Item $p.Dst -Force -Recurse -ErrorAction SilentlyContinue
      } else {
        # Back up OUTSIDE ~\.claude\skills. A "project-scaffold.bak-<stamp>" folder left
        # in there is itself read as a skill, so Claude lists a second, stale copy of this
        # skill under the backup's name. Confirmed on 2026-10-26.
        $bakDir = Join-Path $claudeDir '.backups'
        New-Item -ItemType Directory -Force -Path $bakDir | Out-Null
        $bak = Join-Path $bakDir "$(Split-Path $p.Dst -Leaf).bak-$(Get-Date -Format 'yyyyMMddHHmmss')"
        Warn "$($p.Dst) already exists and is not a link; moving it to $bak"
        Move-Item $p.Dst $bak
      }
    }
    try {
      New-Item -ItemType $p.Kind -Path $p.Dst -Target $p.Src -ErrorAction Stop | Out-Null
      Write-Host "    linked $($p.Dst)"
    } catch {
      try {
        Copy-Item $p.Src $p.Dst -Recurse -Force -ErrorAction Stop
        Write-Host "    copied $($p.Dst) (links unavailable: re-run this script after a git pull)"
      } catch { Warn "could not install $($p.Dst)" }
    }
  }

  # Seed the per-machine config so the skill never probes for the vault or assumes a
  # WSL distro. Written only when absent, so a hand-edited path is never clobbered.
  $cfg = Join-Path $claudeDir 'project-scaffold.config.json'
  if (Test-Path $cfg) {
    Say "Keeping the existing $cfg"
  } else {
    $distro = ''
    # docker-desktop / docker-desktop-data show up in this list and are not usable
    # distros (no user home), so taking the first line blindly can pick one.
    try {
      $distro = ((wsl -l -q) |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and $_ -notlike 'docker-desktop*' } |
        Select-Object -First 1)
    } catch { }
    $obj = [ordered]@{
      vault     = if ($script:WinVaultPath) { $script:WinVaultPath } else { $null }
      wsl       = [bool]$distro
      wslDistro = if ($distro) { $distro } else { $null }
    }
    ($obj | ConvertTo-Json) | Out-File -FilePath $cfg -Encoding utf8
    Say "Wrote $cfg"
  }
}

Install-ProjectScaffold

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
