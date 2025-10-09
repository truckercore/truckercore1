# Flutter build helper (Windows PowerShell)
# Usage: Right-click -> Run with PowerShell or run in terminal: powershell -ExecutionPolicy Bypass -File scripts\flutter_build.ps1
# This script keeps everything related to the Flutter (.dart) app build within this project.

$ErrorActionPreference = "Stop"

function Step([string]$name, [scriptblock]$block) {
  Write-Host "==== $name ====" -ForegroundColor Cyan
  & $block
}

# 0) Check Flutter
Step "Checking flutter" {
  $flutter = (Get-Command flutter -ErrorAction SilentlyContinue)
  if (-not $flutter) { throw "Flutter not found in PATH. Install from https://docs.flutter.dev/get-started/install and reopen terminal." }
  flutter --version
}

# 1) Clean and fetch deps
Step "Cleaning project" { flutter clean }
Step "Getting packages" { flutter pub get }

# 2) Static analysis
Step "Analyzing Dart code" { flutter analyze }

# 3) Build mobile + web (skip platforms not configured)
# Android APK (release)
Step "Building Android APK" {
  try { flutter build apk --release } catch { Write-Warning "Android build skipped/failed: $_" }
}

# iOS (only on macOS hosts)
Step "Building iOS (if on macOS)" {
  if ($env:OS -notlike "*Windows*") {
    try { flutter build ios --release } catch { Write-Warning "iOS build skipped/failed: $_" }
  } else {
    Write-Host "Skipping iOS on Windows host"
  }
}

# Web build
Step "Building Web" {
  try { flutter build web --release } catch { Write-Warning "Web build skipped/failed: $_" }
}

# Windows desktop (requires Windows desktop support enabled)
Step "Building Windows (if supported)" {
  try { flutter build windows --release } catch { Write-Warning "Windows build skipped/failed: $_" }
}

Write-Host "==== Done. Artifacts: ====" -ForegroundColor Green
Write-Host "- Android: build\\app\\outputs\\flutter-apk\\app-release.apk"
Write-Host "- Web: build\\web (static assets)"
Write-Host "- Windows: build\\windows\\runner\\Release (exe)"
