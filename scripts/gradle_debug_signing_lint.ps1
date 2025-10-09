# Fails CI if debug buildType wiring references release or custom signing configs.
# Usage: pwsh -NoProfile -File scripts/gradle_debug_signing_lint.ps1
param()

$gradleKts = "android/app/build.gradle.kts"
if (-not (Test-Path $gradleKts)) {
  Write-Error "File not found: $gradleKts"
  exit 1
}

# Load file content
$lines = Get-Content $gradleKts

$inBuildTypes = $false
$inDebug = $false
$braceDepth = 0
$errors = @()

function Add-Err($msg, $ln) {
  $errors += ("Line {0}: {1}" -f $ln, $msg)
}

for ($i = 0; $i -lt $lines.Count; $i++) {
  $ln = $i + 1
  $line = $lines[$i]
  $t = ($line -replace "//.*$", "").Trim() # strip line comments

  if ($t -match "^buildTypes\s*\{") {
    $inBuildTypes = $true
    $braceDepth = 1
    continue
  }

  if ($inBuildTypes) {
    # Track braces to know when we leave buildTypes
    if ($t -match "\{") { $braceDepth++ }
    if ($t -match "\}") { $braceDepth-- }
    if ($braceDepth -le 0) { $inBuildTypes = $false; $inDebug = $false; continue }

    # Enter/exit debug block
    if ($t -match "^debug\s*\{") { $inDebug = $true }
    if ($inDebug -and $t -match "^\}") { $inDebug = $false }

    if ($inDebug) {
      # Forbidden: pointing to release signing or any custom keystore fields
      if ($t -match "signingConfig\s*=\s*signingConfigs\.getByName\(\"release\"\)") {
        Add-Err "debug.signingConfig must not reference release signing" $ln
      }
      if ($t -match "storeFile|keyAlias|storePassword|keyPassword") {
        Add-Err "Forbidden signing property inside debug block (use default debug signing)" $ln
      }
    }
  }
}

# Positive assertion: debug should set signingConfig to signingConfigs.getByName("debug")
$hasDebugSigning = ($lines -join "`n") -match "buildTypes[\s\S]*?debug\s*\{[\s\S]*?signingConfig\s*=\s*signingConfigs\.getByName\(\"debug\"\)"
if (-not $hasDebugSigning) {
  Add-Err "debug.signingConfig is not explicitly set to signingConfigs.getByName(\"debug\")." 0
}

if ($errors.Count -gt 0) {
  Write-Host "Debug signing lint FAILED:" -ForegroundColor Red
  $errors | ForEach-Object { Write-Host $_ -ForegroundColor Red }
  exit 2
}

Write-Host "Debug signing lint passed." -ForegroundColor Green
exit 0
