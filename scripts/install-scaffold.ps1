# Installs skills/project-scaffold and its /project-scaffold command into
# %USERPROFILE%\.claude as a USER-LEVEL skill, not a plugin: a plugin copy would
# appear under a second name beside the user-level one and the two would collide.
#
# A directory junction and a file hard link both work WITHOUT administrator rights or
# Developer Mode, unlike a symbolic link, and both keep the installed copy pointing at
# the repo so `git pull` updates it in place. Copy-Item is the last resort.
#
# This file is DOT-SOURCED, by setup.ps1 and by scripts/test-install-scaffold.ps1. It
# must define a function and nothing else: no side effects at dot-source time, so a
# test can point -ClaudeDir at a sandbox and assert on the result. Mirrors
# scripts/install-scaffold.sh.

if (-not (Get-Command Say -ErrorAction SilentlyContinue)) {
  function Say($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }
}
if (-not (Get-Command Warn -ErrorAction SilentlyContinue)) {
  function Warn($m) { Write-Host " warning: $m" -ForegroundColor Yellow }
}

function Install-ProjectScaffold {
  [CmdletBinding()]
  param(
    # The checkout to link at. Defaults to this file's parent's parent.
    [string] $RepoDir = (Split-Path (Split-Path $PSCommandPath -Parent) -Parent),
    # Where to install. Defaults to the real ~/.claude; a test passes a sandbox.
    [string] $ClaudeDir = (Join-Path $env:USERPROFILE '.claude'),
    # Vault path for the config. Empty means "vault": null.
    [string] $Vault = '',
    # Skip probing wsl -l -q (a test does not want to depend on WSL being present).
    [switch] $NoWslProbe
  )

  Say "Installing the project-scaffold skill into $ClaudeDir"
  New-Item -ItemType Directory -Force -Path (Join-Path $ClaudeDir 'skills') | Out-Null
  New-Item -ItemType Directory -Force -Path (Join-Path $ClaudeDir 'commands') | Out-Null

  $pairs = @(
    @{ Src = (Join-Path $RepoDir 'skills\project-scaffold'); Dst = (Join-Path $ClaudeDir 'skills\project-scaffold'); Kind = 'Junction' },
    @{ Src = (Join-Path $RepoDir 'commands\project-scaffold.md'); Dst = (Join-Path $ClaudeDir 'commands\project-scaffold.md'); Kind = 'HardLink' }
  )

  foreach ($p in $pairs) {
    if (-not (Test-Path $p.Src)) { Warn "missing $($p.Src); skipping"; continue }
    $existing = Get-Item $p.Dst -Force -ErrorAction SilentlyContinue
    if ($existing) {
      # A junction/link is ours to replace; anything real is the user's, so move it aside.
      if ($existing.LinkType) {
        Remove-Item $p.Dst -Force -Recurse -ErrorAction SilentlyContinue
      } else {
        # Back up OUTSIDE <claude>\skills. A "project-scaffold.bak-<stamp>" folder left
        # in there is itself read as a skill, so Claude lists a second, stale copy of this
        # skill under the backup's name. Confirmed on 2026-10-26.
        $bakDir = Join-Path $ClaudeDir '.backups'
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
  $cfg = Join-Path $ClaudeDir 'project-scaffold.config.json'
  if (Test-Path $cfg) {
    Say "Keeping the existing $cfg"
    return
  }

  $distro = ''
  if (-not $NoWslProbe) {
    # docker-desktop / docker-desktop-data show up in this list and are not usable
    # distros (no user home), so taking the first line blindly can pick one.
    try {
      $distro = ((wsl -l -q) |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and $_ -notlike 'docker-desktop*' } |
        Select-Object -First 1)
    } catch { }
  }

  # ConvertTo-Json escapes the backslashes in a Windows path. Writing this file by
  # hand produces invalid JSON ("C:\Users" fails, because \U is not a legal escape)
  # and the skill then silently falls back to probing. Hit on 2026-10-26.
  $obj = [ordered]@{
    vault     = if ($Vault) { $Vault } else { $null }
    wsl       = [bool]$distro
    wslDistro = if ($distro) { $distro } else { $null }
  }
  ($obj | ConvertTo-Json) | Out-File -FilePath $cfg -Encoding utf8
  Say "Wrote $cfg"
}
