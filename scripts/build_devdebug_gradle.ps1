param(
  [switch]$Info
)
# Build the DevDebug variant using Gradle directly and capture verbose logs
# Usage:
#   pwsh -NoProfile -ExecutionPolicy Bypass -File scripts\build_devdebug_gradle.ps1
#   pwsh -NoProfile -ExecutionPolicy Bypass -File scripts\build_devdebug_gradle.ps1 -Info

$androidDir = Join-Path (Get-Location) "android"
$gradlew = Join-Path $androidDir "gradlew.bat"
if (-not (Test-Path $gradlew)) {
  Write-Error "Gradle wrapper not found at $gradlew"
  exit 1
}

$log = "gradle_build_full.log"
if (Test-Path $log) { Remove-Item $log -Force }

Push-Location $androidDir
try {
  $flags = "--stacktrace --info"
  if ($Info) { $flags = "--stacktrace --info --debug" }
  $cmd = ".\gradlew.bat assembleDevDebug $flags"
  Write-Host "[Gradle] $cmd" -ForegroundColor Cyan
  cmd /c "$cmd > ..\$log 2>&1"
} finally {
  Pop-Location
}

if (-not (Test-Path $log)) {
  Write-Error "Gradle log not found: $log"
  exit 1
}

Write-Host "[Gradle] Build complete. Scanning $log for first error..." -ForegroundColor Green
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts\extract_first_error.ps1 -LogPath $log -Context 5