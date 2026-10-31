# Smoke test for scripts/install-scaffold.ps1. Runs the real installer against a
# throwaway directory, never your actual ~/.claude.
#
#   pwsh -File scripts/test-install-scaffold.ps1
#
# The Windows install path is the least exercised code in this repo and the one most
# likely to break on someone else's machine: it depends on directory junctions and
# file hard links, which behave differently from symlinks and from each other.
# Mirrors scripts/test-install-scaffold.sh.

$ErrorActionPreference = 'Stop'
$RepoDir = Split-Path (Split-Path $PSCommandPath -Parent) -Parent
$script:Fails = 0

function Pass($m) { Write-Host "  ok   $m" }
function Failed($m) { Write-Host "  FAIL $m" -ForegroundColor Red; $script:Fails++ }
function Check($name, $got, $want) {
  if ($got -eq $want) { Pass $name } else { Failed "$name (expected [$want], got [$got])" }
}

# Silence the installer's own chatter; we assert on the filesystem, not the log.
function Say($m) { }
function Warn($m) { }
. (Join-Path $RepoDir 'scripts\install-scaffold.ps1')

$sandbox = Join-Path ([System.IO.Path]::GetTempPath()) "kp-test-$(Get-Random)"
New-Item -ItemType Directory -Force -Path $sandbox | Out-Null

function Get-Vault($cfgPath) {
  (Get-Content -Raw -LiteralPath $cfgPath | ConvertFrom-Json).vault
}

try {
  # --- 1. a clean install --------------------------------------------------
  Write-Host '1. clean install into an empty directory'
  $c1 = Join-Path $sandbox 'clean'
  $vaultFixture = Join-Path $sandbox 'fake-vault'
  New-Item -ItemType Directory -Force -Path $vaultFixture | Out-Null
  Install-ProjectScaffold -RepoDir $RepoDir -ClaudeDir $c1 -Vault $vaultFixture -NoWslProbe | Out-Null

  $skill = Join-Path $c1 'skills\project-scaffold\SKILL.md'
  $cmd = Join-Path $c1 'commands\project-scaffold.md'
  $cfg = Join-Path $c1 'project-scaffold.config.json'

  if (Test-Path $skill) { Pass 'skill installed' } else { Failed 'skill missing' }
  if (Test-Path $cmd) { Pass 'command installed' } else { Failed 'command missing' }
  if (Test-Path $cfg) { Pass 'config written' } else { Failed 'config missing' }

  # Reading SKILL.md through the install path proves the junction actually resolves,
  # which is the whole reason a junction was chosen over a symlink.
  if ((Test-Path $skill) -and (Select-String -LiteralPath $skill -Pattern '^name: project-scaffold' -Quiet)) {
    Pass 'skill readable through the junction'
  } else { Failed 'skill unreadable through the junction' }

  # The config must be valid JSON. Hand-written Windows paths are not: "C:\Users"
  # fails because \U is not a legal escape, and the skill then silently re-probes.
  Check 'config is valid json and records the vault' (Get-Vault $cfg) $vaultFixture

  $linkType = (Get-Item (Join-Path $c1 'skills\project-scaffold') -Force).LinkType
  if ($linkType) { Pass "skill is a link, not a copy ($linkType)" }
  else { Pass 'skill was copied (links unavailable on this runner, fallback worked)' }

  # --- 2. no vault -> null, not an empty string ----------------------------
  Write-Host '2. no vault resolved'
  $c2 = Join-Path $sandbox 'novault'
  Install-ProjectScaffold -RepoDir $RepoDir -ClaudeDir $c2 -Vault '' -NoWslProbe | Out-Null
  Check 'vault is null when none is passed' (Get-Vault (Join-Path $c2 'project-scaffold.config.json')) $null

  # --- 3. a Windows path round-trips through json --------------------------
  Write-Host '3. a Windows-style path round-trips'
  $c3 = Join-Path $sandbox 'winpath'
  $winVault = 'C:\Users\someone\Documents\Knowledge-Vault'
  Install-ProjectScaffold -RepoDir $RepoDir -ClaudeDir $c3 -Vault $winVault -NoWslProbe | Out-Null
  Check 'backslash path round-trips' (Get-Vault (Join-Path $c3 'project-scaffold.config.json')) $winVault

  # --- 4. idempotent, and a hand-edited config survives --------------------
  Write-Host '4. second run is idempotent and preserves the config'
  '{ "vault": "/edited/by/hand", "wsl": true }' | Out-File -FilePath $cfg -Encoding utf8
  Install-ProjectScaffold -RepoDir $RepoDir -ClaudeDir $c1 -Vault $vaultFixture -NoWslProbe | Out-Null
  Check 'hand-edited vault survives a re-run' (Get-Vault $cfg) '/edited/by/hand'
  if (Test-Path $skill) { Pass 'skill still installed after re-run' } else { Failed 're-run broke the install' }

  # --- 5. a real directory is backed up OUTSIDE skills/ --------------------
  # A backup left inside skills/ is itself read as a skill, so Claude lists a
  # second, stale copy of this skill under the backup's name.
  Write-Host '5. an existing real directory is moved aside, not into skills/'
  $c5 = Join-Path $sandbox 'occupied'
  New-Item -ItemType Directory -Force -Path (Join-Path $c5 'skills\project-scaffold') | Out-Null
  New-Item -ItemType Directory -Force -Path (Join-Path $c5 'commands') | Out-Null
  "someone else's skill" | Out-File -FilePath (Join-Path $c5 'skills\project-scaffold\SKILL.md') -Encoding utf8
  Install-ProjectScaffold -RepoDir $RepoDir -ClaudeDir $c5 -Vault '/v' -NoWslProbe | Out-Null

  $strays = @(Get-ChildItem -LiteralPath (Join-Path $c5 'skills') -Filter '*.bak-*' -Force -ErrorAction SilentlyContinue)
  Check 'no backup left inside skills/' $strays.Count 0
  $kept = @(Get-ChildItem -LiteralPath (Join-Path $c5 '.backups') -Filter 'project-scaffold.bak-*' -Force -ErrorAction SilentlyContinue)
  Check 'the displaced directory is kept in .backups' $kept.Count 1
  if (Select-String -LiteralPath (Join-Path $c5 'skills\project-scaffold\SKILL.md') -Pattern '^name: project-scaffold' -Quiet) {
    Pass 'ours is installed in its place'
  } else { Failed 'ours did not replace it' }
}
finally {
  # Junctions must be removed before the directory tree, or Remove-Item can follow
  # one into the repo and delete the real skill.
  Get-ChildItem -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.LinkType } |
    ForEach-Object { try { $_.Delete() } catch { } }
  Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
if ($script:Fails -eq 0) { Write-Host 'all checks passed'; exit 0 }
Write-Host "$($script:Fails) check(s) failed"
exit 1
