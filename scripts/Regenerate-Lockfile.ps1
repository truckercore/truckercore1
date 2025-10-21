Param(
  [switch]$DryRun
)

# Regenerate package-lock.json with Node 18 on Windows, preferring Linux parity via WSL if available.
# Order of preference:
# 1) WSL (Linux parity with Vercel) -> use Node 18 if available in WSL
# 2) nvm-windows -> switch/install Node 18 and run npm install
# 3) Volta -> pin/use node@18 and run npm install
# 4) Fallback to current Windows Node (warn if outside engines range)

$ErrorActionPreference = 'Stop'

function Write-Info($msg) { Write-Host "[lockfile] $msg" -ForegroundColor Cyan }
function Write-Warn($msg) { Write-Host "[lockfile] WARN: $msg" -ForegroundColor Yellow }
function Write-Err($msg) { Write-Host "[lockfile] ERROR: $msg" -ForegroundColor Red }

function Test-Cmd($name) {
  $null -ne (Get-Command $name -ErrorAction SilentlyContinue)
}

function Get-NodeVersion() {
  try {
    $v = node -v 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $v) { return $null }
    return $v.Trim()
  } catch { return $null }
}

function Ensure-EnginesRange($nodeVersion) {
  if (-not $nodeVersion) { return $false }
  # Strip leading 'v'
  $nv = $nodeVersion.TrimStart('v')
  try {
    [version]$ver = $nv
  } catch { return $false }
  $gte18 = $ver.Major -ge 18
  $lt21 = $ver.Major -lt 21
  return ($gte18 -and $lt21)
}

function Run-NpmInstall {
  param([string]$WorkDir)
  Push-Location $WorkDir
  try {
    Write-Info "Removing node_modules and package-lock.json in $WorkDir"
    if (-not $DryRun) {
      if (Test-Path node_modules) { Remove-Item -Recurse -Force node_modules }
      if (Test-Path package-lock.json) { Remove-Item -Force package-lock.json }
    }
    Write-Info "Running: npm install --include=dev --legacy-peer-deps"
    if (-not $DryRun) {
      npm install --include=dev --legacy-peer-deps
    }
    Write-Host "[lockfile] Done. package-lock.json regenerated." -ForegroundColor Green
  } finally {
    Pop-Location
  }
}

function Try-WSL() {
  if (-not (Test-Cmd 'wsl.exe')) { return $false }
  Write-Info "WSL detected. Attempting Linux-parity lockfile regeneration."
  $repo = (Get-Location).Path
  # Ensure path is WSL friendly: use wslpath
  $bashCmd = @(
    "set -euo pipefail",
    "cd \"$(wslpath -a '$repo')\"",
    "rm -rf node_modules package-lock.json",
    "if command -v volta >/dev/null 2>&1; then volta install node@18; fi",
    "if command -v nvm >/dev/null 2>&1; then . \"$HOME/.nvm/nvm.sh\" && nvm install 18 && nvm use 18; fi",
    "node -v || true",
    "npm -v || true",
    "npm install --include=dev --legacy-peer-deps"
  ) -join '; '

  if ($DryRun) {
    Write-Info "[DRY RUN] Would run in WSL: bash -lc \"$bashCmd\""
    return $true
  }

  try {
    wsl.exe bash -lc "$bashCmd"
    if ($LASTEXITCODE -eq 0) {
      Write-Host "[lockfile] Successfully regenerated lockfile via WSL (Linux parity)." -ForegroundColor Green
      return $true
    }
  } catch {
    Write-Warn "WSL path failed: $($_.Exception.Message)"
  }
  return $false
}

function Try-NvmWindows() {
  if (-not (Test-Cmd 'nvm')) { return $false }
  Write-Info "nvm-windows detected. Switching to Node 18."
  if (-not $DryRun) {
    nvm install 18 | Out-Null
    nvm use 18 | Out-Null
  } else {
    Write-Info "[DRY RUN] Would run: nvm install 18 && nvm use 18"
  }
  $ver = Get-NodeVersion
  if (-not (Ensure-EnginesRange $ver)) {
    Write-Warn "Node version after nvm use is $ver (expected >=18 <21)."
  }
  Run-NpmInstall -WorkDir (Get-Location).Path
  return $true
}

function Try-Volta() {
  if (-not (Test-Cmd 'volta')) { return $false }
  Write-Info "Volta detected. Using node@18."
  if (-not $DryRun) {
    volta install node@18 | Out-Null
  } else {
    Write-Info "[DRY RUN] Would run: volta install node@18"
  }
  $ver = Get-NodeVersion
  if (-not (Ensure-EnginesRange $ver)) {
    Write-Warn "Node version after Volta pin is $ver (expected >=18 <21)."
  }
  Run-NpmInstall -WorkDir (Get-Location).Path
  return $true
}

# Main
Write-Info "Starting lockfile regeneration (Windows). DryRun=$DryRun"

if (Try-WSL) { exit 0 }
if (Try-NvmWindows) { exit 0 }
if (Try-Volta) { exit 0 }

$ver = Get-NodeVersion
if (-not (Ensure-EnginesRange $ver)) {
  Write-Warn "Current Node version is '$ver'. Expected >=18 <21 (per package.json engines)."
  Write-Warn "Install nvm-windows (https://github.com/coreybutler/nvm-windows) and run: nvm install 18 && nvm use 18"
}
Run-NpmInstall -WorkDir (Get-Location).Path
exit 0
